// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

// import {PoolV3} from "@gearbox-protocol/core-v3/contracts/pool/PoolV3.sol";
// import {PoolQuotaKeeperV3} from "@gearbox-protocol/core-v3/contracts/pool/PoolQuotaKeeperV3.sol";
// import {GaugeV3} from "@gearbox-protocol/core-v3/contracts/governance/GaugeV3.sol";
// import {CreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/credit/CreditFacadeV3.sol";

// import {CreditManagerV3} from "@gearbox-protocol/core-v3/contracts/credit/CreditManagerV3.sol";

// // TEST
// import "../lib/constants.sol";
// import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";

// // SUITES

// import {LiveEnvHelper} from "../suites/LiveEnvHelper.sol";
// import {IwstETH} from "../../integrations/lido/IwstETH.sol";

// contract LiveV3DeployTest is Test, LiveEnvHelper {
//     function setUp() public liveOnly {
//         _setUp();
//     }

//     /// @dev [V3D-1]: Protocol is deployed as expected
//     function test_live_V3D_01_protocol_is_deployed_as_expected() public liveOnly {
//         CreditFacadeV3 cf = lts.creditFacades(Tokens.USDC);

//         assertTrue(cf.isBlacklistableUnderlying(), "USDC Credit Facade not set to blacklistable");
//         assertEq(
//             cf.blacklistHelper(),
//             address(lts.blacklistHelper()),
//             "USDC Credit Facade blacklist helper not set correctly"
//         );

//         assertTrue(
//             lts.blacklistHelper().isSupportedCreditFacadeV3(address(cf)),
//             "Credit Facade was not added to blacklistHelper"
//         );

//         assertTrue(cf.botList() != address(0), "Bot list was not set");

//         Tokens[] memory underlyings = lts.getSupportedUnderlyings();

//         for (uint256 i = 0; i < underlyings.length; ++i) {
//             CreditManagerV3 cm = lts.CreditManagerV3s(underlyings[i]);

//             assertTrue(cm.supportsQuotas(), "Credit manager does not support quotas");

//             PoolV3 pool = PoolV3(cm.pool());
//             PoolQuotaKeeperV3 pqk = PoolQuotaKeeperV3(pool.poolQuotaKeeper());

//             assertTrue(address(pqk.gauge()) != address(0), "GaugeV3 was not set in PQK");

//             assertTrue(address(pqk.gauge().voter()) == address(lts.gearStaking()), "GearStakingV3 was not set in gauge");

//             address[] memory quotedTokens = pqk.quotedTokens();

//             for (uint256 j = 0; j < quotedTokens.length; ++j) {
//                 assertTrue(
//                     cm.getTokenMaskOrRevert(quotedTokens[j]) & cm.limitedTokenMask() > 0,
//                     "Token is marked as quoted in the pool, but not in the CM"
//                 );
//             }
//         }
//     }
// }
