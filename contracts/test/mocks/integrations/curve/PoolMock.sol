// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

enum PoolType {
    Stable,
    Crypto
}

contract PoolMock {
    PoolType poolType;
    address[] public coins;
    address[] public underlying_coins;

    constructor(PoolType _poolType, address[] memory _coins, address[] memory _underlying_coins) {
        poolType = _poolType;
        coins = _coins;
        underlying_coins = _underlying_coins;
    }

    function isCrypto() public view returns (bool) {
        return poolType == PoolType.Crypto;
    }

    function mid_fee() external view returns (uint256) {
        if (poolType == PoolType.Stable) revert("Not a crypto pool");
        return 0;
    }

    function N_COINS() external view returns (uint256) {
        return coins.length;
    }
}
