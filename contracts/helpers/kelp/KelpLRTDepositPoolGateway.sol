// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;
pragma abicoder v1;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "@gearbox-protocol/core-v3/contracts/interfaces/external/IWETH.sol";
import {ReceiveIsNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {IKelpLRTDepositPoolGateway} from "../../interfaces/kelp/IKelpLRTDepositPoolGateway.sol";
import {IKelpLRTDepositPool} from "../../integrations/kelp/IKelpLRTDepositPool.sol";
import {IKelpLRTConfig} from "../../integrations/kelp/IKelpLRTConfig.sol";

/// @title KelpLRTDepositPoolGateway
/// @notice Allows to deposit into rsETH directly through the Kelp LRTDepositPool, automatically converting WETH to ETH and back.
/// @dev The gateway only supports `depositAsset` interface to simplify logic on upper-level contracts and avoid having to treat WETH separately from
///      other assets.
contract KelpLRTDepositPoolGateway is IKelpLRTDepositPoolGateway {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::KELP_DEPOSIT_POOL";
    uint256 public constant override version = 3_10;

    /// @notice WETH token
    address public immutable weth;

    /// @notice Kelp LRTDepositPool contract address
    address public immutable depositPool;

    /// @notice rsETH token
    address public immutable rsETH;

    /// @notice Constructor
    /// @param _weth WETH token address
    constructor(address _weth, address _depositPool) {
        weth = _weth;
        depositPool = _depositPool;
        address lrtConfig = IKelpLRTDepositPool(depositPool).lrtConfig();
        rsETH = IKelpLRTConfig(lrtConfig).rsETH();
    }

    /// @notice Allows this contract to unwrap WETH, forbids receiving ETH in other ways
    receive() external payable {
        if (msg.sender != weth) revert ReceiveIsNotAllowedException();
    }

    /// @notice Deposits an asset into rsETH
    /// @param asset Asset to deposit
    /// @param amount Amount of asset to deposit
    /// @param minRSETHAmountExpected Minimum amount of rsETH to receive
    /// @param referralId Referral ID
    function depositAsset(address asset, uint256 amount, uint256 minRSETHAmountExpected, string calldata referralId)
        external
    {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        amount = IERC20(asset).balanceOf(address(this));
        if (asset == weth) {
            _depositWETH(amount, minRSETHAmountExpected, referralId);
        } else {
            _depositAsset(asset, amount, minRSETHAmountExpected, referralId);
        }
        IERC20(rsETH).safeTransfer(msg.sender, IERC20(rsETH).balanceOf(address(this)));
    }

    /// @notice Deposits an ERC20 into rsETH
    function _depositAsset(address asset, uint256 amount, uint256 minRSETHAmountExpected, string calldata referralId)
        internal
    {
        IERC20(asset).forceApprove(depositPool, amount);
        IKelpLRTDepositPool(depositPool).depositAsset(asset, amount, minRSETHAmountExpected, referralId);
    }

    /// @notice Deposits WETH into rsETH via unwrapping into native ETH
    function _depositWETH(uint256 amount, uint256 minRSETHAmountExpected, string calldata referralId) internal {
        IWETH(weth).withdraw(amount);
        IKelpLRTDepositPool(depositPool).depositETH{value: amount}(minRSETHAmountExpected, referralId);
    }
}
