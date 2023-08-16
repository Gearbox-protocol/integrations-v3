// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";

struct QuotedTokenParams {
    Tokens token;
    uint16 minRiskRate;
    uint16 maxRate;
    uint96 limit;
}

struct PoolParams {
    uint16 U_optimal;
    uint16 U_reserve;
    uint16 R_base;
    uint16 R_slope1;
    uint16 R_slope2;
    uint16 R_slope3;
    uint256 expectedLiquidityLimit;
    bool supportsQuotas;
    QuotedTokenParams[] quotedTokens;
}

contract PoolConfigLive {
    mapping(Tokens => PoolParams) poolParams;
    Tokens[] underlyings;

    constructor() {
        PoolParams storage pp;

        underlyings.push(Tokens.WETH);
        pp = poolParams[Tokens.WETH];
        pp.U_optimal = 8000;
        pp.U_reserve = 9000;
        pp.R_base = 0;
        pp.R_slope1 = 250;
        pp.R_slope2 = 2000;
        pp.R_slope3 = 10000;
        pp.expectedLiquidityLimit = 30000000000000000000000;
        pp.supportsQuotas = true;
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.CVX, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.FXS, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.LQTY, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.CRV, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.LDO, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.SNX, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        underlyings.push(Tokens.wstETH);
        pp = poolParams[Tokens.wstETH];
        pp.U_optimal = 8000;
        pp.U_reserve = 9000;
        pp.R_base = 0;
        pp.R_slope1 = 250;
        pp.R_slope2 = 2000;
        pp.R_slope3 = 10000;
        pp.expectedLiquidityLimit = 30000000000000000000000;
        pp.supportsQuotas = true;
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.CVX, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.FXS, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.LQTY, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.CRV, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.LDO, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.SNX, minRiskRate: 10, maxRate: 300, limit: 300000000000000000000})
        );
        underlyings.push(Tokens.WBTC);
        pp = poolParams[Tokens.WBTC];
        pp.U_optimal = 8000;
        pp.U_reserve = 9000;
        pp.R_base = 0;
        pp.R_slope1 = 250;
        pp.R_slope2 = 2000;
        pp.R_slope3 = 10000;
        pp.expectedLiquidityLimit = 20000000000;
        pp.supportsQuotas = true;
        pp.quotedTokens.push(QuotedTokenParams({token: Tokens.CVX, minRiskRate: 10, maxRate: 300, limit: 2000000000}));
        pp.quotedTokens.push(QuotedTokenParams({token: Tokens.FXS, minRiskRate: 10, maxRate: 300, limit: 2000000000}));
        pp.quotedTokens.push(QuotedTokenParams({token: Tokens.LQTY, minRiskRate: 10, maxRate: 300, limit: 2000000000}));
        pp.quotedTokens.push(QuotedTokenParams({token: Tokens.CRV, minRiskRate: 10, maxRate: 300, limit: 2000000000}));
        pp.quotedTokens.push(QuotedTokenParams({token: Tokens.LDO, minRiskRate: 10, maxRate: 300, limit: 2000000000}));
        pp.quotedTokens.push(QuotedTokenParams({token: Tokens.SNX, minRiskRate: 10, maxRate: 300, limit: 2000000000}));
        underlyings.push(Tokens.DAI);
        pp = poolParams[Tokens.DAI];
        pp.U_optimal = 8000;
        pp.U_reserve = 9000;
        pp.R_base = 0;
        pp.R_slope1 = 100;
        pp.R_slope2 = 1000;
        pp.R_slope3 = 10000;
        pp.expectedLiquidityLimit = 50000000000000000000000000;
        pp.supportsQuotas = true;
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.CVX, minRiskRate: 10, maxRate: 300, limit: 5000000000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.FXS, minRiskRate: 10, maxRate: 300, limit: 5000000000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.LQTY, minRiskRate: 10, maxRate: 300, limit: 5000000000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.CRV, minRiskRate: 10, maxRate: 300, limit: 5000000000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.LDO, minRiskRate: 10, maxRate: 300, limit: 5000000000000000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.SNX, minRiskRate: 10, maxRate: 300, limit: 5000000000000000000000000})
        );
        underlyings.push(Tokens.USDC);
        pp = poolParams[Tokens.USDC];
        pp.U_optimal = 8000;
        pp.U_reserve = 9000;
        pp.R_base = 0;
        pp.R_slope1 = 100;
        pp.R_slope2 = 1000;
        pp.R_slope3 = 10000;
        pp.expectedLiquidityLimit = 50000000000000;
        pp.supportsQuotas = true;
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.CVX, minRiskRate: 10, maxRate: 300, limit: 5000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.FXS, minRiskRate: 10, maxRate: 300, limit: 5000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.LQTY, minRiskRate: 10, maxRate: 300, limit: 5000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.CRV, minRiskRate: 10, maxRate: 300, limit: 5000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.LDO, minRiskRate: 10, maxRate: 300, limit: 5000000000000})
        );
        pp.quotedTokens.push(
            QuotedTokenParams({token: Tokens.SNX, minRiskRate: 10, maxRate: 300, limit: 5000000000000})
        );
    }
}
