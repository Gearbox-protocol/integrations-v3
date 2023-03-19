// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {GearStaking} from "@gearbox-protocol/core-v3/contracts/support/GearStaking.sol";
import {LinearInterestRateModel} from "@gearbox-protocol/core-v3/contracts/pool/LinearInterestRateModel.sol";
import {Pool4626} from "@gearbox-protocol/core-v3/contracts/pool/Pool4626.sol";
import {PoolQuotaKeeper} from "@gearbox-protocol/core-v3/contracts/pool/PoolQuotaKeeper.sol";
import {Gauge} from "@gearbox-protocol/core-v3/contracts/pool/Gauge.sol";

import {Pool4626Opts} from "@gearbox-protocol/core-v3/contracts/interfaces/IPool4626.sol";
import {GaugeOpts} from "@gearbox-protocol/core-v3/contracts/interfaces/IGauge.sol";

import {Tokens} from "../config/Tokens.sol";
import {PoolConfigLive, PoolParams, QuotedTokenParams} from "../config/PoolConfigLive.sol";

import {CheatCodes, HEVM_ADDRESS} from "@gearbox-protocol/core-v3/contracts/test/lib/cheatCodes.sol";

import {TokensTestSuite} from "./TokensTestSuite.sol";

contract LivePoolDeployer is PoolConfigLive {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);
    GearStaking public gearStaking;
    Pool4626[] public pools;

    constructor(address addressProvider, TokensTestSuite tokenTestSuite, address ROOT_ADDRESS) PoolConfigLive() {
        gearStaking = new GearStaking(
            addressProvider,
            block.timestamp
        );

        for (uint256 i = 0; i < underlyings.length; ++i) {
            PoolParams storage pp = poolParams[underlyings[i]];

            LinearInterestRateModel irm = new LinearInterestRateModel(
                pp.U_optimal,
                pp.U_reserve,
                pp.R_base,
                pp.R_slope1,
                pp.R_slope2,
                pp.R_slope3,
                true
            );

            Pool4626Opts memory poolOpts = Pool4626Opts({
                addressProvider: addressProvider,
                underlyingToken: tokenTestSuite.addressOf(underlyings[i]),
                interestRateModel: address(irm),
                expectedLiquidityLimit: pp.expectedLiquidityLimit,
                supportsQuotas: pp.supportsQuotas
            });

            Pool4626 pool = new Pool4626(poolOpts);

            pools.push(pool);

            PoolQuotaKeeper pqk = new PoolQuotaKeeper(
                address(pool)
            );

            evm.prank(ROOT_ADDRESS);
            pool.connectPoolQuotaManager(address(pqk));

            GaugeOpts memory gaugeOpts =
                GaugeOpts({addressProvider: addressProvider, pool: address(pool), gearStaking: address(gearStaking)});

            Gauge gauge = new Gauge(gaugeOpts);

            evm.prank(ROOT_ADDRESS);
            pqk.setGauge(address(gauge));

            for (uint256 j = 0; j < pp.quotedTokens.length; ++j) {
                QuotedTokenParams memory qToken = pp.quotedTokens[j];

                evm.startPrank(ROOT_ADDRESS);
                gauge.addQuotaToken(tokenTestSuite.addressOf(qToken.token), qToken.minRiskRate, qToken.maxRate);

                pqk.setTokenLimit(tokenTestSuite.addressOf(qToken.token), qToken.limit);
                evm.stopPrank();
            }
        }
    }
}
