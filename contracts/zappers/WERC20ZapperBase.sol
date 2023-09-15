// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";

import {IWERC20Zapper} from "../interfaces/zappers/IWERC20Zapper.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title wERC20 zapper base
/// @notice Base contract for zappers allowing users to deposit/withdraw an ERC20 token
///         to/from a Gearbox pool with its wrapper as underlying in a single operation
/// @dev Default implementation assumes that unwrapped token has no transfer fees
/// @dev Derived zappers must call `_resetWrapperAllowance` in their constructor after
///      initializing `unwrappedToken()`
abstract contract WERC20ZapperBase is ZapperBase, IWERC20Zapper {
    using SafeERC20 for IERC20;

    /// @notice Constructor
    /// @param pool_ Pool to connect this zapper to
    constructor(address pool_) ZapperBase(pool_) {}

    /// @dev Returns uwnrapped token, must be overriden by derived zappers
    function unwrappedToken() public view virtual override returns (address);

    /// @notice Zaps wrapping a token and depositing it to the pool into a single operation
    function deposit(uint256 amount, address receiver) external override returns (uint256 shares) {
        shares = _deposit(amount, receiver);
    }

    /// @notice Same as `deposit` but allows to specify the referral code
    function depositWithReferral(uint256 amount, address receiver, uint16 referralCode)
        external
        override
        returns (uint256 shares)
    {
        shares = _depositWithReferral(amount, receiver, referralCode);
    }

    /// @notice Zaps redeeming token from the pool and unwrapping it into a single operation
    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256 amount) {
        amount = _redeem(shares, receiver, owner);
    }

    /// @dev Receives unwrapped token from `msg.sender` and wraps it
    function _receiveAndWrap(uint256 amount) internal virtual override returns (uint256 wrappedAmount) {
        IERC20(unwrappedToken()).safeTransferFrom(msg.sender, address(this), amount);
        wrappedAmount = _wrap(amount);
        _resetWrapperAllowance();
    }

    /// @dev Unwraps pool's underlying and sends it to `receiver`
    function _unwrapAndSend(uint256 amount, address receiver)
        internal
        virtual
        override
        returns (uint256 unwrappedAmount)
    {
        unwrappedAmount = _unwrap(amount);
        IERC20(unwrappedToken()).safeTransfer(receiver, unwrappedAmount);
    }

    /// @dev Wraps unwrapped token, must be overriden by derived zappers
    function _wrap(uint256 amount) internal virtual returns (uint256);

    /// @dev Unwraps wrapped token, must be overriden by derived zappers
    function _unwrap(uint256 amount) internal virtual returns (uint256);

    /// @dev Gives `wrappedToken` max allowance for this contract's `unwrappedToken()`
    function _resetWrapperAllowance() internal virtual {
        _resetAllowance(unwrappedToken(), wrappedToken);
    }
}
