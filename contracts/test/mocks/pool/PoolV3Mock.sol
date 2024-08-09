// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

contract PoolV3Mock {
    event Deposit(uint256 assets, uint256 shares, address receiver);
    event Redeem(uint256 assets, uint256 shares, address owner, address receiver);
    event Refer(uint256 referralCode);

    address public immutable underlyingToken;
    uint256 internal _pricePerShare;

    constructor(address underlying) {
        underlyingToken = underlying;
    }

    function hackPricePerShare(uint256 pricePerShare) external {
        _pricePerShare = pricePerShare;
    }

    function previewDeposit(uint256 assets) public view returns (uint256 shares) {
        shares = assets * _pricePerShare / 1 ether;
    }

    function previewRedeem(uint256 shares) public view returns (uint256 assets) {
        assets = shares * 1 ether / _pricePerShare;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = previewDeposit(assets);
        emit Deposit(assets, shares, receiver);
    }

    function depositWithReferral(uint256 assets, address receiver, uint256 referralCode)
        external
        returns (uint256 shares)
    {
        shares = previewDeposit(assets);
        emit Deposit(assets, shares, receiver);
        emit Refer(referralCode);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        assets = previewRedeem(shares);
        emit Redeem(assets, shares, owner, receiver);
    }
}
