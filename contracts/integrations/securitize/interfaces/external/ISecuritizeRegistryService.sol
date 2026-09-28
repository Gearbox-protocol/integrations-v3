// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ISecuritizeRegistryService {
    function isWallet(address wallet) external view returns (bool);
}
