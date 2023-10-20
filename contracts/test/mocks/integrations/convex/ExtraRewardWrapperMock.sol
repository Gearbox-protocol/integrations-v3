// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

contract ExtraRewardWrapperMock {
    address public token;

    constructor(address _token) {
        token = _token;
    }
}
