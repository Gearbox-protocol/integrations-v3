// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";

struct RatesAndLimits {
    Tokens token;
    uint16 minRiskRate;
    uint16 maxRate;
    uint16 quotaIncreaseFee;
    uint96 limit;
}

struct LIRMParams {
    uint16 U_optimal;
    uint16 U_reserve;
    uint16 R_base;
    uint16 R_slope1;
    uint16 R_slope2;
    uint16 R_slope3;
}

struct PoolParams {
    uint256 expectedLiquidityLimit;
    bool supportsQuotas;
}

// contract PoolV3DeployConfig {
//     string public immutable symbol;
//     string public immutable name;
//     uint256 public immutable chainId;

//     Tokens public immutable underlying;
//     LIRMParams public immutable irm;
//     RatesAndLimits[] public quotedTokens;
// }
