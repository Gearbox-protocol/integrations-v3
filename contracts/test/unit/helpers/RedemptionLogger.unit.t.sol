// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {RedemptionLogger} from "../../../helpers/RedemptionLogger.sol";
import {IRedemptionLogger} from "../../../interfaces/IRedemptionLogger.sol";

/// @title RedemptionLogger unit test
/// @notice U:[RL]: Unit tests for RedemptionLogger
contract RedemptionLoggerUnitTest is Test {
    RedemptionLogger logger;

    address creditAccount;
    address redeemer;
    address gateway;

    function setUp() public {
        logger = new RedemptionLogger();
        creditAccount = makeAddr("CREDIT_ACCOUNT");
        redeemer = makeAddr("REDEEMER");
        gateway = makeAddr("GATEWAY");
    }

    /// @notice U:[RL-1]: `logRedemption` stores data and emits an event
    function test_U_RL_01_logRedemption_stores_and_emits() public {
        bytes memory extraData = abi.encode(uint256(42));

        logger.setGatewayAllowed(gateway, true);

        vm.expectEmit(true, true, false, true);
        emit IRedemptionLogger.RedemptionLogged(creditAccount, redeemer, extraData);

        vm.prank(gateway);
        logger.logRedemption(creditAccount, redeemer, extraData);

        IRedemptionLogger.RedemptionLog memory log = logger.redemptionLogs(redeemer);
        assertEq(log.creditAccount, creditAccount, "Incorrect stored credit account");
        assertEq(log.redeemer, redeemer, "Incorrect stored redeemer");
        assertEq(log.extraData, extraData, "Incorrect stored extraData");
    }

    /// @notice U:[RL-1A]: `logRedemption` reverts for non-allowed gateway
    function test_U_RL_01A_logRedemption_reverts_for_non_allowed_gateway() public {
        vm.prank(gateway);
        vm.expectRevert(IRedemptionLogger.GatewayNotAllowedException.selector);
        logger.logRedemption(creditAccount, redeemer, "");
    }

    /// @notice U:[RL-1B]: `setGatewayAllowed` can only be called by owner
    function test_U_RL_01B_setGatewayAllowed_reverts_for_non_owner() public {
        vm.prank(gateway);
        vm.expectRevert();
        logger.setGatewayAllowed(gateway, true);
    }

    /// @notice U:[RL-2]: `redemptionLogs` returns empty data for unknown redeemer
    function test_U_RL_02_redemptionLogs_returns_empty_for_unknown_redeemer() public {
        address unknownRedeemer = makeAddr("UNKNOWN_REDEEMER");
        IRedemptionLogger.RedemptionLog memory log = logger.redemptionLogs(unknownRedeemer);

        assertEq(log.creditAccount, address(0), "Unexpected credit account");
        assertEq(log.redeemer, address(0), "Unexpected redeemer");
        assertEq(log.extraData.length, 0, "Unexpected extraData");
    }
}
