// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {IPoolV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPoolV3.sol";
import {IZapper} from "../interfaces/zappers/IZapper.sol";

/// @title Zapper base
/// @notice Base contract for zappers that combine depositing/redeeming funds to/from a Gearbox pool
///         and other operations, such as wrapping tokens or staking pool shares, into a single call
abstract contract ZapperBase is IZapper {
    using SafeERC20 for IERC20;

    /// @notice Pool this zapper is connected to
    address public immutable pool;

    /// @notice `pool`'s underlying token
    address public immutable underlying;

    /// @notice Constructor
    /// @param pool_ Pool to connect a new zapper to
    constructor(address pool_) {
        pool = pool_; // U:[ZB-1]
        underlying = IPoolV3(pool_).underlyingToken(); // U:[ZB-1]
        _resetAllowance(underlying, pool); // U:[ZB-1]
    }

    /// @notice Zapper's input token
    function tokenIn() public view virtual returns (address);

    /// @notice Zapper's output token
    function tokenOut() public view virtual returns (address);

    // ------- //
    // PREVIEW //
    // ------- //

    /// @notice Returns the amount of `tokenOut` one would receive by depositing `tokenInAmount` of `tokenIn`
    function previewDeposit(uint256 tokenInAmount) external view returns (uint256 tokenOutAmount) {
        uint256 assets = tokenIn() == underlying ? tokenInAmount : _previewTokenInToUnderlying(tokenInAmount); // U:[ZB-2]
        uint256 shares = IPoolV3(pool).previewDeposit(assets); // U:[ZB-2]
        tokenOutAmount = tokenOut() == pool ? shares : _previewSharesToTokenOut(shares); // U:[ZB-2]
    }

    /// @notice Returns the amount of `tokenIn` one would receive by redeeming `tokenOutAmount` of `tokenOut`
    function previewRedeem(uint256 tokenOutAmount) external view returns (uint256 tokenInAmount) {
        uint256 shares = tokenOut() == pool ? tokenOutAmount : _previewTokenOutToShares(tokenOutAmount); // U:[ZB-3]
        uint256 assets = IPoolV3(pool).previewRedeem(shares); // U:[ZB-3]
        tokenInAmount = tokenIn() == underlying ? assets : _previewUnderlyingToTokenIn(assets); // U:[ZB-3]
    }

    /// @dev Returns the amount of `underlying` one would receive by converting `tokenInAmount` of `tokenIn`
    function _previewTokenInToUnderlying(uint256 tokenInAmount) internal view virtual returns (uint256 assets);

    /// @dev Returns the amount of `tokenIn` one would receive by converting `assets` of `underlying`
    function _previewUnderlyingToTokenIn(uint256 assets) internal view virtual returns (uint256 tokenInAmount);

    /// @dev Returns the amount of `tokenOut` one would receive by converting `shares` of `pool`'s shares
    function _previewSharesToTokenOut(uint256 shares) internal view virtual returns (uint256 tokenOutAmount);

    /// @dev Returns the amount of `pool`'s shares one would receive by converting `tokenOutAmount` of `tokenOut`
    function _previewTokenOutToShares(uint256 tokenOutAmount) internal view virtual returns (uint256 shares);

    // --- //
    // ZAP //
    // --- //

    /// @notice Performs redeem zap:
    ///         - receives `tokenOut` from `msg.sender` and converts it to `pool`'s shares
    ///         - redeems `pool`'s shares for `underlying`
    ///         - converts `underlying` to `tokenIn` and sends it to `receiver`
    /// @dev Requires approval from `msg.sender` for `tokenOut` to this contract
    function redeem(uint256 tokenOutAmount, address receiver) external returns (uint256 tokenInAmount) {
        tokenInAmount = _redeem(tokenOutAmount, receiver, msg.sender);
    }

    /// @notice Performs redeem zap using signed EIP-2612 permit message for zapper's output token:
    ///         - receives `tokenOut` from `msg.sender` and converts it to `pool`'s shares
    ///         - redeems `pool`'s shares for `underlying`
    ///         - converts `underlying` to `tokenIn` and sends it to `receiver`
    /// @dev `v`, `r`, `s` must be a valid signature of the permit message from `msg.sender` for `tokenOut` to this contract
    function redeemWithPermit(uint256 tokenOutAmount, address receiver, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 tokenInAmount)
    {
        try IERC20Permit(tokenOut()).permit(msg.sender, address(this), tokenOutAmount, deadline, v, r, s) {} catch {} // U:[ZB-5]
        tokenInAmount = _redeem(tokenOutAmount, receiver, msg.sender);
    }

    /// @dev `deposit` and `depositWithReferral` implementation
    /// @dev If `tokenOut` is `pool`, skips `_sharesToTokenOut` and mints shares directly to `receiver` on deposit
    function _deposit(uint256 tokenInAmount, address receiver, bool withReferral, uint256 referralCode)
        internal
        virtual
        returns (uint256 tokenOutAmount)
    {
        bool tokenOutIsPool = tokenOut() == pool;
        uint256 assets = _tokenInToUnderlying(tokenInAmount); // U:[ZB-4]
        uint256 shares = withReferral
            ? IPoolV3(pool).depositWithReferral(assets, tokenOutIsPool ? receiver : address(this), referralCode)
            : IPoolV3(pool).deposit(assets, tokenOutIsPool ? receiver : address(this)); // U:[ZB-4]
        tokenOutAmount = tokenOutIsPool ? shares : _sharesToTokenOut(shares, receiver); // U:[ZB-4]
    }

    /// @dev `redeem` and `redeemWithReferral` implementation
    /// @dev If `tokenOut` is `pool`, skips `_tokenOutToShares` and burns shares directly from `owner` on redeem
    /// @dev If `tokenIn` is `underlying`, skips `_underlyingToTokenIn` and sends tokens directly to `receiver` on redeem
    function _redeem(uint256 tokenOutAmount, address receiver, address owner)
        internal
        virtual
        returns (uint256 tokenInAmount)
    {
        bool tokenOutIsPool = tokenOut() == pool;
        bool tokenInIsUnderlying = tokenIn() == underlying;
        uint256 shares = tokenOutIsPool ? tokenOutAmount : _tokenOutToShares(tokenOutAmount, owner); // U:[ZB-5]
        uint256 assets = IPoolV3(pool).redeem({
            shares: shares,
            receiver: tokenInIsUnderlying ? receiver : address(this),
            owner: tokenOutIsPool ? owner : address(this)
        }); // U:[ZB-5]
        tokenInAmount = tokenInIsUnderlying ? assets : _underlyingToTokenIn(assets, receiver); // U:[ZB-5]
    }

    /// @dev Receives `tokenInAmount` of `tokenIn` from `msg.sender` and converts it to `underlying`
    function _tokenInToUnderlying(uint256 tokenInAmount) internal virtual returns (uint256 assets);

    /// @dev Converts `assets` of `underlying` to `tokenIn` and sends it to `receiver`
    function _underlyingToTokenIn(uint256 assets, address receiver) internal virtual returns (uint256 tokenInAmount);

    /// @dev Converts `shares` of `pool`'s shares to `tokenOut` and sends it to `receiver`
    function _sharesToTokenOut(uint256 shares, address receiver) internal virtual returns (uint256 tokenOutAmount);

    /// @dev Receives `tokenOutAmount` of `tokenOut` from `owner` and converts it to `pool`'s shares
    function _tokenOutToShares(uint256 tokenOutAmount, address owner) internal virtual returns (uint256 shares);

    // --------- //
    // INTERNALS //
    // --------- //

    /// @dev Gives `spender` max allowance for this contract's `token`
    function _resetAllowance(address token, address spender) internal {
        IERC20(token).forceApprove(spender, type(uint256).max);
    }
}
