// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {GearStakingV3} from "@gearbox-protocol/core-v3/contracts/governance/GearStakingV3.sol";
import {LinearInterestRateModelV3} from "@gearbox-protocol/core-v3/contracts/pool/LinearInterestRateModelV3.sol";
import {PoolV3} from "@gearbox-protocol/core-v3/contracts/pool/PoolV3.sol";
import {PoolQuotaKeeperV3} from "@gearbox-protocol/core-v3/contracts/pool/PoolQuotaKeeperV3.sol";
import {GaugeV3} from "@gearbox-protocol/core-v3/contracts/governance/GaugeV3.sol";
import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";
import {AddressProvider} from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";
import {PoolConfigLive, PoolParams, QuotedTokenParams} from "../config/PoolConfigLive.sol";

import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";

contract LivePoolDeployer is PoolConfigLive {
// GearStakingV3 public gearStaking;
// PoolV3[] internal _pools;

// constructor(address addressProvider, TokensTestSuite tokenTestSuite, address ROOT_ADDRESS) PoolConfigLive() {
//     gearStaking = new GearStakingV3(
//         addressProvider,
//         block.timestamp
//     );

//     for (uint256 i = 0; i < underlyings.length; ++i) {
//         PoolParams storage pp = poolParams[underlyings[i]];

//         LinearInterestRateModelV3 irm = new LinearInterestRateModelV3(
//             pp.U_optimal,
//             pp.U_reserve,
//             pp.R_base,
//             pp.R_slope1,
//             pp.R_slope2,
//             pp.R_slope3,
//             true
//         );

//         PoolV3Opts memory poolOpts = PoolV3Opts({
//             addressProvider: addressProvider,
//             underlyingToken: tokenTestSuite.addressOf(underlyings[i]),
//             interestRateModel: address(irm),
//             expectedLiquidityLimit: pp.expectedLiquidityLimit,
//             supportsQuotas: pp.supportsQuotas
//         });

//         PoolV3 pool = new PoolV3(poolOpts);

//         _pools.push(pool);

//         ContractsRegister cr = ContractsRegister(AddressProvider(addressProvider).getContractsRegister());

//         vm.prank(ROOT_ADDRESS);
//         cr.addPool(address(pool));

//         PoolQuotaKeeperV3 pqk = new PoolQuotaKeeperV3(
//             address(pool)
//         );

//         vm.prank(ROOT_ADDRESS);
//         pool.connectPoolQuotaManager(address(pqk));

//         GaugeV3Opts memory gaugeOpts = GaugeV3Opts({pool: address(pool), gearStaking: address(gearStaking)});

//         GaugeV3 gauge = new GaugeV3(gaugeOpts);

//         vm.prank(ROOT_ADDRESS);
//         pqk.setGaugeV3(address(gauge));

//         for (uint256 j = 0; j < pp.quotedTokens.length; ++j) {
//             QuotedTokenParams memory qToken = pp.quotedTokens[j];

//             vm.startPrank(ROOT_ADDRESS);
//             gauge.addQuotaToken(tokenTestSuite.addressOf(qToken.token), qToken.minRiskRate, qToken.maxRate);

//             pqk.setTokenLimit(tokenTestSuite.addressOf(qToken.token), qToken.limit);
//             vm.stopPrank();
//         }
//     }
// }

// function pools() external view returns (PoolV3[] memory) {
//     return _pools;
// }
}
