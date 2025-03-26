// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {TraderJoeRouterAdapter} from "../../../../adapters/traderjoe/TraderJoeRouterAdapter.sol";
import {Path} from "../../../../integrations/traderjoe/ITraderJoeRouter.sol";

/// @title TraderJoeRouterAdapter harness
/// @notice Exposes internal functions in TraderJoeRouterAdapter
contract TraderJoeRouterAdapterHarness is TraderJoeRouterAdapter {
    constructor(address _creditManager, address _router) TraderJoeRouterAdapter(_creditManager, _router) {}

    /// @notice Exposes internal _validatePath function
    function validatePath(Path memory path) external view returns (bool valid, address tokenIn) {
        return _validatePath(path);
    }
}
