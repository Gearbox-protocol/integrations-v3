// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";

import {IPoolV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPoolV3.sol";

import {IZapper} from "../interfaces/zappers/IZapper.sol";

/// @title Zapper base
/// @notice Base contract for zappers allowing users to deposit/withdraw an unwrapped token
///         to/from a Gearbox pool with wrapped token as underlying in a single operation
abstract contract ZapperBase is IZapper {
    using SafeERC20 for IERC20;

    /// @notice Pool this zapper is connected to
    address public immutable override pool;

    /// @notice Underlying token of the pool
    address public immutable override wrappedToken;

    /// @notice Token this zapper returns when deposit (underlying / staked one)
    address public immutable override tokenOut;

    /// @notice Constructor
    /// @param pool_ Pool to connect this zapper to
    constructor(address pool_) {
        pool = pool_;
        wrappedToken = IPoolV3(pool_).asset();
        tokenOut = pool_;
        _resetPoolAllowance();
    }

    /// @notice Returns number of pool shares one would receive for depositing `amount` of unwrapped token
    function previewDeposit(uint256 amount) external view override returns (uint256 shares) {
        uint256 assets = _previewWrap(amount);
        return IPoolV3(pool).previewDeposit(assets);
    }

    /// @notice Returns amount of unwrapped token one would receive for redeeming `shares` of pool shares
    function previewRedeem(uint256 shares) external view override returns (uint256 amount) {
        uint256 assets = IPoolV3(pool).previewRedeem(shares);
        return _previewUnwrap(assets);
    }

    /// @dev Implementation of deposit zap
    ///      - Receives `amount` of unwrapped token from `msg.sender` and wraps it
    ///      - Deposits wrapped token into the pool and mints pool shares to `receiver`
    function _deposit(uint256 amount, address receiver) internal virtual returns (uint256 shares) {
        uint256 assets = _receiveAndWrap(amount);
        shares = IPoolV3(pool).deposit(assets, receiver);
        _resetPoolAllowance();
    }

    /// @dev Same as `_deposit` but allows to specify the referral code
    function _depositWithReferral(uint256 amount, address receiver, uint16 referralCode)
        internal
        virtual
        returns (uint256 shares)
    {
        uint256 assets = _receiveAndWrap(amount);
        shares = IPoolV3(pool).depositWithReferral(assets, receiver, referralCode);
        _resetPoolAllowance();
    }

    /// @dev Implementation of redeem zap
    ///      - Burns `owner`'s pool shares and redeems wrapped token (requires `owner`'s approval)
    ///      - Unwraps redeemed token and sends `amount` of unwrapped token to `receiver`
    function _redeem(uint256 shares, address receiver, address owner) internal virtual returns (uint256 amount) {
        uint256 assets = IPoolV3(pool).redeem(shares, address(this), owner);
        amount = _unwrapAndSend(assets, receiver);
    }

    /// @dev Receives unwrapped token from `msg.sender` and wraps it, must be overriden by derived zappers
    function _receiveAndWrap(uint256 amount) internal virtual returns (uint256 wrappedAmount);

    /// @dev Unwraps pool's underlying and sends it to `receiver`, must be overriden by derived zappers
    function _unwrapAndSend(uint256 amount, address receiver) internal virtual returns (uint256 unwrappedAmount);

    /// @dev Returns amount of wrapped token one would receive for wrapping `amount` of unwrapped token,
    ///      must be overriden by derived zappers
    function _previewWrap(uint256 amount) internal view virtual returns (uint256 wrappedAmount);

    /// @dev Returns amount of unwrapped token one would receive for unwrapping `amount` of wrapped token,
    ///      must be overriden by derived zappers
    function _previewUnwrap(uint256 amount) internal view virtual returns (uint256 unwrappedAmount);

    /// @dev Gives `pool` max allowance for the `wrappedToken`
    function _resetPoolAllowance() internal virtual {
        _resetAllowance(wrappedToken, pool);
    }

    /// @dev Gives `spender` max allowance for this contract's `token`
    function _resetAllowance(address token, address spender) internal {
        IERC20(token).forceApprove(spender, type(uint256).max);
    }
}
