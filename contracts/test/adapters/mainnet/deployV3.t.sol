// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Pool4626} from "@gearbox-protocol/core-v3/contracts/pool/Pool4626.sol";
import {PoolQuotaKeeper} from "@gearbox-protocol/core-v3/contracts/pool/PoolQuotaKeeper.sol";
import {Gauge} from "@gearbox-protocol/core-v3/contracts/pool/Gauge.sol";
import {CreditFacade} from "@gearbox-protocol/core-v3/contracts/credit/CreditFacade.sol";

import {CreditManager} from "@gearbox-protocol/core-v3/contracts/credit/CreditManager.sol";

// TEST
import "../../lib/constants.sol";
import {Tokens} from "../../config/Tokens.sol";

// SUITES

import {LiveEnvHelper} from "../../suites/LiveEnvHelper.sol";
import {IwstETH} from "../../../integrations/lido/IwstETH.sol";

contract LiveV3DeployTest is DSTest, LiveEnvHelper {
    function setUp() public liveOnly {
        _setUp();
    }

    /// @dev [V3D-1]: Protocol is deployed as expected
    function test_live_V3D_01_protocol_is_deployed_as_expected() public liveOnly {
        CreditFacade cf = lts.creditFacades(Tokens.USDC);

        assertTrue(cf.isBlacklistableUnderlying(), "USDC Credit Facade not set to blacklistable");
        assertEq(
            cf.blacklistHelper(),
            address(lts.blacklistHelper()),
            "USDC Credit Facade blacklist helper not set correctly"
        );

        assertTrue(
            lts.blacklistHelper().isSupportedCreditFacade(address(cf)), "Credit Facade was not added to blacklistHelper"
        );

        assertTrue(cf.botList() != address(0), "Bot list was not set");

        Tokens[] memory underlyings = lts.getSupportedUnderlyings();

        for (uint256 i = 0; i < underlyings.length; ++i) {
            CreditManager cm = lts.creditManagers(underlyings[i]);

            assertTrue(cm.supportsQuotas(), "Credit manager does not support quotas");

            Pool4626 pool = Pool4626(cm.pool());
            PoolQuotaKeeper pqk = PoolQuotaKeeper(pool.poolQuotaKeeper());

            assertTrue(address(pqk.gauge()) != address(0), "Gauge was not set in PQK");

            assertTrue(address(pqk.gauge().voter()) == address(lts.gearStaking()), "GearStaking was not set in gauge");

            address[] memory quotedTokens = pqk.quotedTokens();

            for (uint256 j = 0; j < quotedTokens.length; ++j) {
                assertTrue(
                    cm.tokenMasksMap(quotedTokens[j]) & cm.limitedTokenMask() > 0,
                    "Token is marked as quoted in the pool, but not in the CM"
                );
            }
        }
    }
}
