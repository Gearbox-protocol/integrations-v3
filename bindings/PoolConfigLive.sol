// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {Tokens} from "./Tokens.sol";

struct QuotedTokenParams {
    Tokens token;
    uint16 minRiskRate;
    uint16 maxRate;
    uint96 limit;
}

struct PoolParams {
    uint256 U_optimal;
    uint256 U_reserve;
    uint256 R_base;
    uint256 R_slope1;
    uint256 R_slope2;
    uint256 R_slope3;
    uint256 expectedLiquidityLimit;
    bool supportsQuotas;
    QuotedTokenParams[] quotedTokens;
}

contract PoolConfigLive {
    mapping(Tokens => PoolParams) poolParams;
    Tokens[] underlyings;

    constructor() {
        PoolParams storage pp;

        // $POOL_CONFIG
    }
}
