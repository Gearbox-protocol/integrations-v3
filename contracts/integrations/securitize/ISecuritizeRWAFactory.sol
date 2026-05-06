// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ISecuritizeRWAFactory {
    function isCreditAccount(address creditAccount) external view returns (bool);
}
