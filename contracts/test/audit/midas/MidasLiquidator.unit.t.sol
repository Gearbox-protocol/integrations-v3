// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";

import {MidasGateway} from "../../../helpers/midas/MidasGateway.sol";
import {MidasLiquidator} from "../../../helpers/midas/MidasLiquidator.sol";
import {IMidasLiquidator} from "../../../interfaces/midas/IMidasLiquidator.sol";

import "./MidasAuditTestBase.sol";

/// @title Midas liquidator unit tests
/// @notice U:[MID-LIQ]: Unit tests for MidasLiquidator, which currently has zero coverage.
///         Covers collateral forwarding, transfer-flag lifecycle, validation reverts, and
///         the residual-sweep finding (MID-R15).
contract MidasLiquidatorUnitTest is MidasAuditTestBase {
    AuditCreditFacade internal facade;
    address internal collateralToken;
    address internal otherToken;
    address internal liquidatorEOA;

    function setUp() public {
        _deployGateway18(true, false, address(0));

        facade = new AuditCreditFacade(address(creditManager));
        creditManager.setCreditFacade(address(facade));
        creditManager.setAdapter(address(gateway), makeAddr("ADAPTER"));

        collateralToken = address(new ERC20Mock("COLL", "COLL", 18));
        otherToken = address(new ERC20Mock("OTHER", "OTHER", 6));
        liquidatorEOA = makeAddr("LIQUIDATOR_EOA");
    }

    function _addCollateralCall(address token, uint256 amount) internal view returns (MultiCall memory) {
        return MultiCall({
            target: msg.sender, // placeholder, overwritten by caller
            callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (token, amount))
        });
    }

    function noop() external pure {}

    /*
     * @test-id: tst_core_midas_040
     * @scenario: scn_midas_liq_forward_001
     * @covers: contracts/helpers/midas/MidasLiquidator.sol::liquidateWithRedeemerTransfers
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant inv_mid_liq_02: a single addCollateral call is pre-funded from the liquidator
     * EOA, approved to the credit manager, consumed by the facade, and no leftover remains.
     */
    function test_tst_core_midas_040_single_addcollateral_is_forwarded_and_consumed() public {
        uint256 amount = 100e18;
        deal(collateralToken, liquidatorEOA, amount);

        MultiCall[] memory calls = new MultiCall[](1);
        calls[0] = MultiCall({
            target: address(facade),
            callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (collateralToken, amount))
        });

        vm.startPrank(liquidatorEOA);
        IERC20(collateralToken).approve(address(liquidator), amount);
        liquidator.liquidateWithRedeemerTransfers(address(account), address(gateway), calls, "");
        vm.stopPrank();

        assertEq(IERC20(collateralToken).balanceOf(liquidatorEOA), 0, "EOA funded the full amount");
        assertEq(IERC20(collateralToken).balanceOf(address(liquidator)), 0, "liquidator holds no residual");
        assertEq(IERC20(collateralToken).balanceOf(address(facade)), amount, "facade received the collateral");
        assertEq(IERC20(collateralToken).allowance(address(liquidator), address(creditManager)), 0, "allowance reset");
        assertFalse(liquidator.isTransferAllowed(), "transfer flag reset after call");
    }

    /*
     * @test-id: tst_core_midas_041
     * @scenario: scn_midas_liq_forward_002
     * @covers: contracts/helpers/midas/MidasLiquidator.sol::_forwardCollateral
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant: multiple addCollateral calls with different tokens are all pre-funded and
     * consumed; the transfer flag is raised exactly during the facade call.
     */
    function test_tst_core_midas_041_multiple_addcollateral_different_tokens() public {
        uint256 amtA = 100e18;
        uint256 amtB = 50e6;
        deal(collateralToken, liquidatorEOA, amtA);
        deal(otherToken, liquidatorEOA, amtB);

        MultiCall[] memory calls = new MultiCall[](2);
        calls[0] = MultiCall({
            target: address(facade),
            callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (collateralToken, amtA))
        });
        calls[1] = MultiCall({
            target: address(facade),
            callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (otherToken, amtB))
        });

        vm.startPrank(liquidatorEOA);
        IERC20(collateralToken).approve(address(liquidator), amtA);
        IERC20(otherToken).approve(address(liquidator), amtB);
        liquidator.liquidateWithRedeemerTransfers(address(account), address(gateway), calls, "");
        vm.stopPrank();

        assertEq(IERC20(collateralToken).balanceOf(address(facade)), amtA, "facade received COLL");
        assertEq(IERC20(otherToken).balanceOf(address(facade)), amtB, "facade received OTHER");
        assertEq(IERC20(collateralToken).balanceOf(address(liquidator)), 0, "no COLL residual");
        assertEq(IERC20(otherToken).balanceOf(address(liquidator)), 0, "no OTHER residual");
    }

    /*
     * @test-id: tst_core_midas_042
     * @scenario: scn_midas_liq_revert_transfer_master_001
     * @covers: contracts/helpers/midas/MidasLiquidator.sol::liquidateWithRedeemerTransfers
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant inv_mid_liq_01: reverts when the gateway's transferMaster is not this liquidator.
     */
    function test_tst_core_midas_042_reverts_when_transfer_master_mismatches() public {
        // Deploy a different gateway whose transferMaster is a different liquidator.
        AuditMidasIssuanceVault otherIssuance = new AuditMidasIssuanceVault(mToken);
        AuditMidasRedemptionVault otherRedemption = new AuditMidasRedemptionVault(mToken, address(dataFeed));
        MidasGateway otherGateway = new MidasGateway(
            address(otherIssuance), address(otherRedemption), quoteToken18, false, address(0), false, 1 days, true, address(addressProvider)
        );

        MultiCall[] memory calls = new MultiCall[](0);
        vm.expectRevert(IMidasLiquidator.NotValidGatewayException.selector);
        vm.prank(liquidatorEOA);
        liquidator.liquidateWithRedeemerTransfers(address(account), address(otherGateway), calls, "");
    }

    /*
     * @test-id: tst_core_midas_043
     * @scenario: scn_midas_liq_revert_no_adapter_001
     * @covers: contracts/helpers/midas/MidasLiquidator.sol::liquidateWithRedeemerTransfers
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant: reverts when the gateway has no registered adapter in the credit manager.
     */
    function test_tst_core_midas_043_reverts_when_gateway_has_no_adapter() public {
        creditManager.setAdapter(address(gateway), address(0));
        MultiCall[] memory calls = new MultiCall[](0);
        vm.expectRevert(IMidasLiquidator.NotValidGatewayException.selector);
        vm.prank(liquidatorEOA);
        liquidator.liquidateWithRedeemerTransfers(address(account), address(gateway), calls, "");
    }

    /*
     * @test-id: tst_core_midas_044
     * @scenario: scn_midas_liq_flag_lifecycle_001
     * @covers: contracts/helpers/midas/MidasLiquidator.sol::isTransferAllowed
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant: isTransferAllowed is true only during the facade call and reset to false
     * afterwards, even when the facade call reverts (state is rolled back).
     */
    function test_tst_core_midas_044_transfer_flag_reset_after_reverting_liquidation() public {
        facade.setLiquidateRevert(true);
        MultiCall[] memory calls = new MultiCall[](0);

        vm.expectRevert("facade: liquidation unavailable");
        vm.prank(liquidatorEOA);
        liquidator.liquidateWithRedeemerTransfers(address(account), address(gateway), calls, "");

        // The whole tx reverted, so isTransferAllowed is rolled back to false.
        assertFalse(liquidator.isTransferAllowed(), "flag rolled back after revert");
    }

    /*
     * @test-id: tst_core_midas_045
     * @scenario: scn_midas_liq_residual_sweep_001
     * @covers: contracts/helpers/midas/MidasLiquidator.sol::_forwardCollateral
     * @deterministic: yes
     * @fixtures: none
     *
     * Finding MID-R15: _forwardCollateral(true) returns the ENTIRE residual balance of each
     * addCollateral token to the current caller. If a prior liquidation (or a direct donation)
     * left tokens on the liquidator contract, the next liquidation's caller can sweep them.
     */
    function test_tst_core_midas_045_residual_balance_is_swept_to_next_liquidator_caller() public {
        // Simulate a leftover balance on the liquidator from a prior operation.
        uint256 leftover = 42e18;
        deal(collateralToken, address(liquidator), leftover);

        // A new liquidation by a different EOA adds 10e18 via addCollateral.
        address newLiquidatorEOA = makeAddr("NEW_LIQUIDATOR");
        uint256 newAmount = 10e18;
        deal(collateralToken, newLiquidatorEOA, newAmount);

        MultiCall[] memory calls = new MultiCall[](1);
        calls[0] = MultiCall({
            target: address(facade),
            callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (collateralToken, newAmount))
        });

        vm.startPrank(newLiquidatorEOA);
        IERC20(collateralToken).approve(address(liquidator), newAmount);
        liquidator.liquidateWithRedeemerTransfers(address(account), address(gateway), calls, "");
        vm.stopPrank();

        // The new caller receives both the unconsumed newAmount AND the pre-existing leftover.
        // The facade consumed 10e18 (the addCollateral amount), so residual = leftover.
        // But _forwardCollateral(true) transfers the ENTIRE balance, which is the leftover.
        assertEq(
            IERC20(collateralToken).balanceOf(newLiquidatorEOA),
            leftover,
            "new caller sweeps pre-existing residual (MID-R15)"
        );
        assertEq(IERC20(collateralToken).balanceOf(address(liquidator)), 0, "liquidator fully drained");
    }

    /*
     * @test-id: tst_core_midas_046
     * @scenario: scn_midas_liq_non_addcollateral_ignored_001
     * @covers: contracts/helpers/midas/MidasLiquidator.sol::_forwardCollateral
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant: calls that do not target the facade or do not match the addCollateral
     * selector are ignored by _forwardCollateral (no token movement, no approval changes).
     */
    function test_tst_core_midas_046_non_addcollateral_calls_are_ignored_by_forwarding() public {
        // A call targeting a non-facade address with addCollateral selector — ignored.
        // A call targeting the facade with a different (no-op) selector — ignored by forwarding.
        MultiCall[] memory calls = new MultiCall[](2);
        calls[0] = MultiCall({
            target: makeAddr("NOT_FACADE"),
            callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (collateralToken, 100e18))
        });
        calls[1] = MultiCall({target: address(facade), callData: abi.encodeCall(AuditCreditFacade.noop, ())});

        vm.prank(liquidatorEOA);
        liquidator.liquidateWithRedeemerTransfers(address(account), address(gateway), calls, "");

        // No collateral was pre-pulled from the EOA since no valid addCollateral was forwarded.
        assertEq(IERC20(collateralToken).balanceOf(address(liquidator)), 0, "no residual from ignored calls");
        assertEq(IERC20(collateralToken).allowance(address(liquidator), address(creditManager)), 0, "no approval set");
        assertFalse(liquidator.isTransferAllowed(), "flag reset");
    }

    /*
     * @test-id: tst_core_midas_047
     * @scenario: scn_midas_liq_duplicate_addcollateral_same_token_001
     * @covers: contracts/helpers/midas/MidasLiquidator.sol::_forwardCollateral
     * @deterministic: yes
     * @fixtures: none
     *
     * Invariant: two addCollateral calls for the same token are both pre-funded cumulatively
     * (the second forceApprove overwrites with the new full balance) and both consumed.
     */
    function test_tst_core_midas_047_duplicate_addcollateral_same_token_accumulates() public {
        uint256 amt1 = 30e18;
        uint256 amt2 = 70e18;
        uint256 total = amt1 + amt2;
        deal(collateralToken, liquidatorEOA, total);

        MultiCall[] memory calls = new MultiCall[](2);
        calls[0] = MultiCall({
            target: address(facade),
            callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (collateralToken, amt1))
        });
        calls[1] = MultiCall({
            target: address(facade),
            callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (collateralToken, amt2))
        });

        vm.startPrank(liquidatorEOA);
        IERC20(collateralToken).approve(address(liquidator), total);
        liquidator.liquidateWithRedeemerTransfers(address(account), address(gateway), calls, "");
        vm.stopPrank();

        assertEq(IERC20(collateralToken).balanceOf(address(facade)), total, "facade received both amounts");
        assertEq(IERC20(collateralToken).balanceOf(address(liquidator)), 0, "no residual");
        assertEq(IERC20(collateralToken).balanceOf(liquidatorEOA), 0, "EOA funded the total");
    }
}
