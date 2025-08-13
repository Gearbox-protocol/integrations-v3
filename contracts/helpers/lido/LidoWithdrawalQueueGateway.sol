// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DoubleEndedQueue} from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IWETH} from "@gearbox-protocol/core-v3/contracts/interfaces/external/IWETH.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";
import {ReceiveIsNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {ILidoWithdrawalQueue, WithdrawalRequestStatus} from "../../integrations/lido/ILidoWithdrawalQueue.sol";
import {IstETHGetters} from "../../integrations/lido/IstETH.sol";

import {ILidoWithdrawalQueueGateway} from "../../interfaces/lido/ILidoWithdrawalQueueGateway.sol";

struct PendingWithdrawal {
    uint256 untransferredWETH;
    DoubleEndedQueue.Bytes32Deque requestIds;
}

/// @title Lido Withdrawal Queue Gateway
/// @notice Allows to redeem wstETH / stETH into WETH directly through Lido
contract LidoWithdrawalQueueGateway is ILidoWithdrawalQueueGateway {
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::LIDO_WITHDRAWAL_QUEUE";
    uint256 public constant override version = 3_10;

    address public immutable withdrawalQueue;

    address public immutable steth;

    address public immutable wsteth;

    address public immutable weth;

    mapping(address => PendingWithdrawal) internal pendingWithdrawals;

    constructor(address _withdrawalQueue, address _weth) {
        withdrawalQueue = _withdrawalQueue;
        weth = _weth;
        steth = ILidoWithdrawalQueue(withdrawalQueue).STETH();
        wsteth = ILidoWithdrawalQueue(withdrawalQueue).WSTETH();
    }

    /// @notice Requests withdrawals from stETH in Lido queue
    function requestWithdrawals(uint256[] calldata amounts) external returns (uint256[] memory requestIds) {
        return _requestWithdrawals(amounts, false);
    }

    /// @notice Requests withdrawals from wstETH in Lido queue
    function requestWithdrawalsWstETH(uint256[] calldata amounts) external returns (uint256[] memory requestIds) {
        return _requestWithdrawals(amounts, true);
    }

    /// @dev Internal implementation of `requestWithdrawals` and `requestWithdrawalsWstETH`
    /// @dev Only 10 withdrawal requests can be active at a time to prevent too much gas
    ///      being spent on pending WETH calculation. This is equivalent to 10000 stETH max.
    function _requestWithdrawals(uint256[] calldata amounts, bool isWstETH)
        internal
        returns (uint256[] memory requestIds)
    {
        if (_getRequestIds(msg.sender).length + amounts.length > 10) {
            revert("WithdrawalQueueGateway: Too many active withdrawals");
        }

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        IERC20(isWstETH ? wsteth : steth).transferFrom(msg.sender, address(this), totalAmount);
        IERC20(isWstETH ? wsteth : steth).forceApprove(withdrawalQueue, totalAmount);

        requestIds = isWstETH
            ? ILidoWithdrawalQueue(withdrawalQueue).requestWithdrawalsWstETH(amounts, address(this))
            : ILidoWithdrawalQueue(withdrawalQueue).requestWithdrawals(amounts, address(this));

        for (uint256 i = 0; i < requestIds.length; i++) {
            pendingWithdrawals[msg.sender].requestIds.pushBack(bytes32(requestIds[i]));
        }

        return requestIds;
    }

    /// @notice Claims finalized withdrawals from Lido and transfers the requested WETH amount
    /// @param amount Amount of WETH to claim
    /// @dev All finalized requests are removed from the list, since they are converted to untransferred WETH
    function claimWithdrawals(uint256 amount) external {
        PendingWithdrawal storage pendingWithdrawal = pendingWithdrawals[msg.sender];

        uint256[] memory requestIds = _getRequestIds(msg.sender);

        (uint256[] memory finalizedRequestIds,,) = _getRequestInfo(requestIds);

        uint256[] memory hints = _getRequestHints(finalizedRequestIds);

        uint256 balanceBefore = address(this).balance;

        ILidoWithdrawalQueue(withdrawalQueue).claimWithdrawals(finalizedRequestIds, hints);

        pendingWithdrawal.untransferredWETH += address(this).balance - balanceBefore;

        if (pendingWithdrawal.untransferredWETH < amount) {
            revert("WithdrawalQueueGateway: Not enough WETH to claim");
        }

        pendingWithdrawal.untransferredWETH -= amount;

        IERC20(weth).transfer(msg.sender, amount);

        for (uint256 i = 0; i < finalizedRequestIds.length; i++) {
            pendingWithdrawal.requestIds.popFront();
        }
    }

    /// @notice Returns the amount of WETH that is pending withdrawal, including claimable WETH
    function getPendingWETH(address account) external view returns (uint256) {
        PendingWithdrawal storage pendingWithdrawal = pendingWithdrawals[account];

        uint256[] memory requestIds = _getRequestIds(account);

        (
            uint256[] memory finalizedRequestIds,
            uint256[] memory unfinalizedStETHAmounts,
            uint256[] memory unfinalizedShareAmounts
        ) = _getRequestInfo(requestIds);

        uint256[] memory hints = _getRequestHints(finalizedRequestIds);

        uint256[] memory claimableAmounts =
            ILidoWithdrawalQueue(withdrawalQueue).getClaimableEther(finalizedRequestIds, hints);

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < claimableAmounts.length; i++) {
            totalAmount += claimableAmounts[i];
        }

        uint256 totalShares = IstETHGetters(steth).getTotalShares();
        uint256 totalPooledEther = IstETHGetters(steth).getTotalPooledEther();

        for (uint256 i = 0; i < unfinalizedStETHAmounts.length; i++) {
            uint256 amountByShares = unfinalizedShareAmounts[i] * totalPooledEther / totalShares;
            totalAmount += amountByShares < unfinalizedStETHAmounts[i] ? amountByShares : unfinalizedStETHAmounts[i];
        }

        totalAmount += pendingWithdrawal.untransferredWETH;

        return totalAmount;
    }

    /// @notice Returns the amount of claimable WETH
    function getClaimableWETH(address account) external view returns (uint256) {
        PendingWithdrawal storage pendingWithdrawal = pendingWithdrawals[account];

        uint256[] memory requestIds = _getRequestIds(account);

        (uint256[] memory finalizedRequestIds,,) = _getRequestInfo(requestIds);

        uint256[] memory hints = _getRequestHints(finalizedRequestIds);

        uint256[] memory claimableAmounts =
            ILidoWithdrawalQueue(withdrawalQueue).getClaimableEther(finalizedRequestIds, hints);

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < claimableAmounts.length; i++) {
            totalAmount += claimableAmounts[i];
        }

        totalAmount += pendingWithdrawal.untransferredWETH;

        return totalAmount;
    }

    /// @dev Returns the IDs of finalized requests, as well as stETH and share amounts of unfinalized requests
    function _getRequestInfo(uint256[] memory requestIds)
        internal
        view
        returns (
            uint256[] memory finalizedRequestIds,
            uint256[] memory unfinalizedStETHAmounts,
            uint256[] memory unfinalizedShareAmounts
        )
    {
        WithdrawalRequestStatus[] memory statuses =
            ILidoWithdrawalQueue(withdrawalQueue).getWithdrawalStatus(requestIds);

        uint256 finalizedCount = 0;

        for (uint256 i = 0; i < requestIds.length; i++) {
            if (statuses[i].isFinalized) {
                finalizedCount++;
            }
        }

        finalizedRequestIds = new uint256[](finalizedCount);

        uint256 index = 0;

        for (uint256 i = 0; i < requestIds.length; i++) {
            if (statuses[i].isFinalized) {
                finalizedRequestIds[index] = requestIds[i];
                index++;
            }
        }

        unfinalizedStETHAmounts = new uint256[](requestIds.length - finalizedCount);
        unfinalizedShareAmounts = new uint256[](requestIds.length - finalizedCount);

        index = 0;

        for (uint256 i = finalizedCount; i < requestIds.length; i++) {
            unfinalizedStETHAmounts[index] = statuses[i].amountOfStETH;
            unfinalizedShareAmounts[index] = statuses[i].amountOfShares;
            index++;
        }

        return (finalizedRequestIds, unfinalizedStETHAmounts, unfinalizedShareAmounts);
    }

    /// @dev Returns the IDs of the active withdrawal requests for an account
    function _getRequestIds(address account) internal view returns (uint256[] memory requestIds) {
        PendingWithdrawal storage pendingWithdrawal = pendingWithdrawals[account];
        uint256 numRequests = pendingWithdrawal.requestIds.length();
        requestIds = new uint256[](numRequests);
        for (uint256 i = 0; i < numRequests; i++) {
            requestIds[i] = uint256(pendingWithdrawal.requestIds.at(i));
        }
        return requestIds;
    }

    /// @dev Returns the checkpoint hints for the active withdrawal requests
    function _getRequestHints(uint256[] memory requestIds) internal view returns (uint256[] memory hints) {
        uint256 lastCheckpointIndex = ILidoWithdrawalQueue(withdrawalQueue).getLastCheckpointIndex();
        return ILidoWithdrawalQueue(withdrawalQueue).findCheckpointHints(requestIds, 0, lastCheckpointIndex);
    }

    receive() external payable {
        if (msg.sender != withdrawalQueue) {
            revert("WithdrawalQueueGateway: Only withdrawal queue can send ETH");
        }

        IWETH(weth).deposit{value: msg.value}();
    }
}
