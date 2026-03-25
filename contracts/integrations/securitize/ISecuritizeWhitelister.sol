// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

struct Signature {
    uint256 deadline;
    bytes signature;
}

struct RegisterMessage {
    address token;
    Signature signature;
}

interface ISecuritizeWhitelister {
    function registerHelperAccount(address creditAccount, address helperAccount, RegisterMessage calldata message)
        external;
}
