// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {IPoolV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPoolV3.sol";
import {IZapper} from "../interfaces/zappers/IZapper.sol";

abstract contract ZapperBase is IZapper {
    using SafeERC20 for IERC20;

    address public immutable pool;

    address public immutable underlying;

    constructor(address pool_) {
        pool = pool_;
        underlying = IPoolV3(pool_).underlyingToken();
        _resetAllowance(underlying, pool);
    }

    function tokenIn() public view virtual returns (address);

    function tokenOut() public view virtual returns (address);

    // ------- //
    // PREVIEW //
    // ------- //

    function previewDeposit(uint256 tokenInAmount) external view returns (uint256 tokenOutAmount) {
        uint256 assets = tokenIn() == underlying ? tokenInAmount : _previewTokenInToUnderlying(tokenInAmount);
        uint256 shares = IPoolV3(pool).previewDeposit(assets);
        tokenOutAmount = tokenOut() == pool ? shares : _previewSharesToTokenOut(shares);
    }

    function previewRedeem(uint256 tokenOutAmount) external view returns (uint256 tokenInAmount) {
        uint256 shares = tokenOut() == pool ? tokenOutAmount : _previewTokenOutToShares(tokenOutAmount);
        uint256 assets = IPoolV3(pool).previewRedeem(shares);
        tokenInAmount = tokenIn() == underlying ? assets : _previewUnderlyingToTokenIn(assets);
    }

    function _previewTokenInToUnderlying(uint256 tokenInAmount) internal view virtual returns (uint256 assets);

    function _previewUnderlyingToTokenIn(uint256 assets) internal view virtual returns (uint256 tokenInAmount);

    function _previewSharesToTokenOut(uint256 shares) internal view virtual returns (uint256 tokenOutAmount);

    function _previewTokenOutToShares(uint256 tokenOutAmount) internal view virtual returns (uint256 shares);

    // --- //
    // ZAP //
    // --- //

    function redeem(uint256 tokenOutAmount, address receiver, address owner) external returns (uint256 tokenInAmount) {
        tokenInAmount = _redeem(tokenOutAmount, receiver, owner);
    }

    function redeemWithPermit(
        uint256 tokenOutAmount,
        address receiver,
        address owner,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 tokenInAmount) {
        try IERC20Permit(tokenOut()).permit(owner, address(this), tokenOutAmount, deadline, v, r, s) {} catch {}
        tokenInAmount = _redeem(tokenOutAmount, receiver, owner);
    }

    function _deposit(uint256 tokenInAmount, address receiver) internal virtual returns (uint256 tokenOutAmount) {
        bool tokenOutIsPool = tokenOut() == pool;

        uint256 assets = _tokenInToUnderlying(tokenInAmount);
        uint256 shares = IPoolV3(pool).deposit({assets: assets, receiver: tokenOutIsPool ? receiver : address(this)});
        tokenOutAmount = tokenOutIsPool ? shares : _sharesToTokenOut(shares, receiver);
    }

    function _depositWithReferral(uint256 tokenInAmount, address receiver, uint256 referralCode)
        internal
        virtual
        returns (uint256 tokenOutAmount)
    {
        bool tokenOutIsPool = tokenOut() == pool;

        uint256 assets = _tokenInToUnderlying(tokenInAmount);
        uint256 shares = IPoolV3(pool).depositWithReferral({
            assets: assets,
            receiver: tokenOutIsPool ? receiver : address(this),
            referralCode: referralCode
        });
        tokenOutAmount = tokenOutIsPool ? shares : _sharesToTokenOut(shares, receiver);
    }

    function _redeem(uint256 tokenOutAmount, address receiver, address owner)
        internal
        virtual
        returns (uint256 tokenInAmount)
    {
        bool tokenOutIsPool = tokenOut() == pool;
        bool tokenInIsUnderlying = tokenIn() == underlying;

        uint256 shares = tokenOutIsPool ? tokenOutAmount : _tokenOutToShares(tokenOutAmount, owner);
        uint256 assets = IPoolV3(pool).redeem({
            shares: shares,
            receiver: tokenInIsUnderlying ? receiver : address(this),
            owner: tokenOutIsPool ? owner : address(this)
        });
        tokenInAmount = tokenInIsUnderlying ? assets : _underlyingToTokenIn(assets, receiver);
    }

    function _tokenInToUnderlying(uint256 tokenInAmount) internal virtual returns (uint256 assets);

    function _underlyingToTokenIn(uint256 assets, address receiver) internal virtual returns (uint256 tokenInAmount);

    function _sharesToTokenOut(uint256 shares, address receiver) internal virtual returns (uint256 tokenOutAmount);

    function _tokenOutToShares(uint256 tokenOutAmount, address owner) internal virtual returns (uint256 shares);

    // --------- //
    // INTERNALS //
    // --------- //

    /// @dev Gives `spender` max allowance for this contract's `token`
    function _resetAllowance(address token, address spender) internal {
        IERC20(token).forceApprove(spender, type(uint256).max);
    }
}
