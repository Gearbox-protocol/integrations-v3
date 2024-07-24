// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {UniswapV2Adapter} from "../../../../adapters/uniswap/UniswapV2.sol";

contract UniswapV2AdapterHarness is UniswapV2Adapter {
    constructor(address creditManager, address router) UniswapV2Adapter(creditManager, router) {}

    function validatePath(address[] memory path) external view returns (bool valid, address tokenIn) {
        (valid, tokenIn) = _validatePath(path);
    }
}
