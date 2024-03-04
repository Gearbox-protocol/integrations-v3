// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {CamelotV3Adapter} from "../../../../adapters/camelot/CamelotV3Adapter.sol";

contract CamelotV3AdapterHarness is CamelotV3Adapter {
    constructor(address creditManager, address router) CamelotV3Adapter(creditManager, router) {}

    function validatePath(bytes memory path) external view returns (bool valid, address tokenIn, address tokenOut) {
        (valid, tokenIn, tokenOut) = _validatePath(path);
    }
}
