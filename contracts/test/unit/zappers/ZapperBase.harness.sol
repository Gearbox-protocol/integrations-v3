// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {ZapperBase} from "../../../zappers/ZapperBase.sol";

contract ZapperBaseHarness is ZapperBase {
    event ConvertTokenInToUnderlying(uint256 tokenInAmount, uint256 assets);
    event ConvertUnderlyingToTokenIn(uint256 assets, uint256 tokenInAmount, address receiver);
    event ConvertSharesToTokenOut(uint256 shares, uint256 tokenOutAmount, address receiver);
    event ConvertTokenOutToShares(uint256 tokenOutAmount, uint256 shares, address owner);

    address _tokenIn;
    address _tokenOut;
    uint256 _tokenInExchangeRate;
    uint256 _tokenOutExchangeRate;

    constructor(address pool_) ZapperBase(pool_) {
        _tokenIn = underlying;
        _tokenOut = pool;
    }

    function hackTokenIn(address token) external {
        _tokenIn = token;
    }

    function hackTokenOut(address token) external {
        _tokenOut = token;
    }

    function hackTokenInExchangeRate(uint256 rate) external {
        _tokenInExchangeRate = rate;
    }

    function hackTokenOutExchangeRate(uint256 rate) external {
        _tokenOutExchangeRate = rate;
    }

    function tokenIn() public view override returns (address) {
        return _tokenIn;
    }

    function tokenOut() public view override returns (address) {
        return _tokenOut;
    }

    function deposit(uint256 tokenInAmount, address receiver) external returns (uint256 tokenOutAmount) {
        tokenOutAmount = _deposit(tokenInAmount, receiver, false, 0);
    }

    function depositWithReferral(uint256 tokenInAmount, address receiver, uint256 referralCode)
        external
        returns (uint256 tokenOutAmount)
    {
        tokenOutAmount = _deposit(tokenInAmount, receiver, true, referralCode);
    }

    function _previewTokenInToUnderlying(uint256 tokenInAmount) internal view override returns (uint256 assets) {
        assets = tokenInAmount * _tokenInExchangeRate / 1 ether;
    }

    function _previewUnderlyingToTokenIn(uint256 assets) internal view override returns (uint256 tokenInAmount) {
        tokenInAmount = assets * 1 ether / _tokenInExchangeRate;
    }

    function _previewSharesToTokenOut(uint256 shares) internal view override returns (uint256 tokenOutAmount) {
        tokenOutAmount = shares * 1 ether / _tokenOutExchangeRate;
    }

    function _previewTokenOutToShares(uint256 tokenOutAmount) internal view override returns (uint256 shares) {
        shares = tokenOutAmount * _tokenOutExchangeRate / 1 ether;
    }

    function _tokenInToUnderlying(uint256 tokenInAmount) internal override returns (uint256 assets) {
        assets = _previewTokenInToUnderlying(tokenInAmount);
        emit ConvertTokenInToUnderlying(tokenInAmount, assets);
    }

    function _underlyingToTokenIn(uint256 assets, address receiver) internal override returns (uint256 tokenInAmount) {
        tokenInAmount = _previewUnderlyingToTokenIn(assets);
        emit ConvertUnderlyingToTokenIn(assets, tokenInAmount, receiver);
    }

    function _sharesToTokenOut(uint256 shares, address receiver) internal override returns (uint256 tokenOutAmount) {
        tokenOutAmount = _previewSharesToTokenOut(shares);
        emit ConvertSharesToTokenOut(shares, tokenOutAmount, receiver);
    }

    function _tokenOutToShares(uint256 tokenOutAmount, address owner) internal override returns (uint256 shares) {
        shares = _previewTokenOutToShares(tokenOutAmount);
        emit ConvertTokenOutToShares(tokenOutAmount, shares, owner);
    }
}
