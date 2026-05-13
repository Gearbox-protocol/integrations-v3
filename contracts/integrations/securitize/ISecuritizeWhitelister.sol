// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ISecuritizeWhitelister {
    function registerHelperAccount(address creditAccount, address helperAccount, address token) external;
}
