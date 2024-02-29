// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ICurveV1Adapter} from "./ICurveV1Adapter.sol";

/// @title Adapter for Curve stable pools with dynamic arrays
interface ICurveV1_StableNGAdapter is ICurveV1Adapter {
    function add_liquidity(uint256[] calldata amounts, uint256)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function remove_liquidity(uint256, uint256[] calldata)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function remove_liquidity_imbalance(uint256[] calldata amounts, uint256)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
