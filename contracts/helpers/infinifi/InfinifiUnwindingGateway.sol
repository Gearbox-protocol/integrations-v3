// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

import {
    IInfinifiGateway,
    IInfinifiLockingController,
    IInfinifiUnwindingModule,
    UnwindingPosition
} from "../../integrations/infinifi/IInfinifiGateway.sol";

import {IInfinifiUnwindingGateway, UserUnwindingData} from "../../interfaces/infinifi/IInfinifiUnwindingGateway.sol";

/// @title Infinifi Withdrawal Gateway
contract InfinifiUnwindingGateway is IInfinifiUnwindingGateway {
    bytes32 public constant override contractType = "GATEWAY::INFINIFI_UNWINDING";
    uint256 public constant override version = 3_10;

    uint256 internal constant EPOCH = 1 weeks;
    uint256 internal constant EPOCH_OFFSET = 3 days;

    address public immutable iUSD;

    address public immutable infinifiGateway;

    address public immutable lockingController;

    address public immutable unwindingModule;

    uint256 public lastUnwindingTimestamp;

    mapping(address => UserUnwindingData) public userToUnwindingData;

    constructor(address _infinifiGateway) {
        infinifiGateway = _infinifiGateway;
        iUSD = IInfinifiGateway(infinifiGateway).getAddress("receiptToken");
        lockingController = IInfinifiGateway(infinifiGateway).getAddress("lockingController");
        unwindingModule = IInfinifiLockingController(lockingController).unwindingModule();
    }

    function startUnwinding(uint256 shares, uint32 unwindingEpochs) external {
        if (block.timestamp == lastUnwindingTimestamp) revert MoreThanOneUnwindingPerBlockException();

        UserUnwindingData storage userUnwindingData = userToUnwindingData[msg.sender];
        if (userUnwindingData.unwindingTimestamp != 0) revert UserAlreadyUnwindingException();

        address lockedToken = IInfinifiLockingController(lockingController).shareToken(unwindingEpochs);

        IERC20(lockedToken).transferFrom(msg.sender, address(this), shares);
        IERC20(lockedToken).approve(infinifiGateway, shares);

        userUnwindingData.shares = shares;
        userUnwindingData.unwindingTimestamp = block.timestamp;
        userUnwindingData.isWithdrawn = false;
        userUnwindingData.unwindingEpochs = unwindingEpochs;
        lastUnwindingTimestamp = block.timestamp;

        IInfinifiGateway(infinifiGateway).startUnwinding(shares, unwindingEpochs);
    }

    function withdraw(uint256 amount) external {
        UserUnwindingData memory userUnwindingData = userToUnwindingData[msg.sender];
        if (userUnwindingData.unwindingTimestamp == 0) revert UserNotUnwindingException();

        uint256 claimableTimestamp = _getClaimableTimestamp(userUnwindingData);

        if (block.timestamp < claimableTimestamp) revert UnwindingNotClaimableException();

        if (!userUnwindingData.isWithdrawn) {
            address lockedToken =
                IInfinifiLockingController(lockingController).shareToken(userUnwindingData.unwindingEpochs);
            uint256 balanceBefore = IERC20(lockedToken).balanceOf(address(this));
            IInfinifiGateway(infinifiGateway).withdraw(userUnwindingData.unwindingTimestamp);
            userUnwindingData.isWithdrawn = true;
            userUnwindingData.unclaimedAssets = IERC20(lockedToken).balanceOf(address(this)) - balanceBefore;
        }

        uint256 pendingAssets = _getPendingAssets(userUnwindingData);
        if (pendingAssets < amount) revert InsufficientPendingAssetsException();

        userUnwindingData.unclaimedAssets -= amount;
        IERC20(iUSD).transfer(msg.sender, amount);

        if (userUnwindingData.unclaimedAssets == 0) {
            userUnwindingData.unwindingTimestamp = 0;
            userUnwindingData.shares = 0;
            userUnwindingData.unclaimedAssets = 0;
            userUnwindingData.unwindingEpochs = 0;
            userUnwindingData.isWithdrawn = false;
        }

        userToUnwindingData[msg.sender] = userUnwindingData;
    }

    function getPendingAssets(address user) public view returns (uint256) {
        return _getPendingAssets(userToUnwindingData[user]);
    }

    function _getPendingAssets(UserUnwindingData memory userUnwindingData) internal view returns (uint256) {
        if (userUnwindingData.unwindingTimestamp == 0) return 0;

        return userUnwindingData.isWithdrawn
            ? userUnwindingData.unclaimedAssets
            : IInfinifiUnwindingModule(unwindingModule).balanceOf(address(this), userUnwindingData.unwindingTimestamp);
    }

    function _getClaimableTimestamp(UserUnwindingData memory userUnwindingData) internal view returns (uint256) {
        UnwindingPosition memory position =
            IInfinifiUnwindingModule(unwindingModule).positions(_unwindingId(userUnwindingData.unwindingTimestamp));

        uint256 claimableEpoch = position.toEpoch;

        return claimableEpoch * EPOCH + EPOCH_OFFSET;
    }

    function _unwindingId(uint256 unwindingTimestamp) internal view returns (bytes32) {
        return keccak256(abi.encode(address(this), unwindingTimestamp));
    }
}
