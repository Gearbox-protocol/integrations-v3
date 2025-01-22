// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {EqualizerRouterAdapter, Route} from "../../../../adapters/equalizer/EqualizerRouterAdapter.sol";

contract EqualizerRouterAdapterHarness is EqualizerRouterAdapter {
    constructor(address creditManager, address router) EqualizerRouterAdapter(creditManager, router) {}

    function validatePath(Route[] memory routes)
        external
        view
        returns (bool valid, address tokenIn, address tokenOut)
    {
        return _validatePath(routes);
    }
}
