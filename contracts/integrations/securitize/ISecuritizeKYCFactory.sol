// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ISecuritizeKYCFactory {
    function isCreditAccount(address creditAccount) external view returns (bool);
}
