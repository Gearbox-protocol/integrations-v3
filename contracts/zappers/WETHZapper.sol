// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IWETH} from "@gearbox-protocol/core-v2/contracts/interfaces/external/IWETH.sol";
import {ReceiveIsNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {ZapperBase} from "./ZapperBase.sol";

/// @title WETH zapper
/// @notice Allows users to deposit/withdraw pure ETH to/from a WETH pool in a single operation
contract WETHZapper is ZapperBase {
    /// @notice Constructor
    /// @param pool_ Pool to connect this zapper to
    constructor(address pool_) ZapperBase(pool_) {}

    /// @notice Allows this contract to unwrap WETH and forbids other direct ETH transfers
    receive() external payable {
        if (msg.sender != wrappedToken) revert ReceiveIsNotAllowedException();
    }

    /// @notice Zaps wrapping ETH and depositing it to the pool into a single operation
    function deposit(address receiver) external payable returns (uint256 shares) {
        shares = _deposit(msg.value, receiver);
    }

    /// @notice Same as `deposit` but allows to specify the referral code
    function depositWithReferral(address receiver, uint16 referralCode) external payable returns (uint256 shares) {
        shares = _depositWithReferral(msg.value, receiver, referralCode);
    }

    /// @notice Zaps redeeming WETH from the pool and unwrapping it into a single operation
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 amount) {
        amount = _redeem(shares, receiver, owner);
    }

    /// @dev Wraps ETH
    function _receiveAndWrap(uint256 amount) internal override returns (uint256 wrappedAmount) {
        IWETH(wrappedToken).deposit{value: amount}();
        return amount;
    }

    /// @dev Unwraps WETH and sends it to `receiver`
    function _unwrapAndSend(uint256 amount, address receiver) internal override returns (uint256 unwrappedAmount) {
        IWETH(wrappedToken).withdraw(amount);
        Address.sendValue(payable(receiver), amount);
        return amount;
    }

    /// @dev Pool has infinite WETH allowance so this step can be skipped
    function _ensurePoolAllowance(uint256) internal override {}
}
