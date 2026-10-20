// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {IACL} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IACL.sol";
import {ILossPolicy} from "@gearbox-protocol/core-v3/contracts/interfaces/base/ILossPolicy.sol";
import {IPriceFeedStore, PriceUpdate} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeedStore.sol";
import {ICreditFacadeV3, MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {
    CollateralCalcTask,
    CollateralDebtData,
    ICreditManagerV3
} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {
    CreditAccountNotLiquidatableWithLossException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {LossPolicyMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/core/LossPolicyMock.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {LiquidationChecksTrait} from "../../../../integrations/common/LiquidationChecksTrait.sol";

contract LiquidationChecksTraitHarness is LiquidationChecksTrait {
    function cutOnDemandPriceUpdates(address creditFacade, MultiCall[] calldata calls)
        external
        pure
        returns (MultiCall[] memory, PriceUpdate[] memory)
    {
        return _cutOnDemandPriceUpdates(creditFacade, calls);
    }

    function applyPriceUpdates(address creditFacade, PriceUpdate[] memory priceUpdates) external {
        _applyPriceUpdates(creditFacade, priceUpdates);
    }

    function revertIfNotAllowedToLiquidate(
        address creditFacade,
        address creditManager,
        address creditAccount,
        address caller,
        bytes memory lossPolicyData
    ) external {
        _revertIfNotAllowedToLiquidate(creditFacade, creditManager, creditAccount, caller, lossPolicyData);
    }

    function hasBadDebt(address creditManager, CollateralDebtData memory cdd) external view returns (bool) {
        return _hasBadDebt(creditManager, cdd);
    }
}

/// @title LiquidationChecksTrait unit test
/// @notice U:[LCT]: Unit tests for LiquidationChecksTrait
contract LiquidationChecksTraitUnitTest is Test {
    LiquidationChecksTraitHarness harness;

    address creditFacade;
    address creditManager;
    address creditAccount;
    address acl;
    address priceFeedStore;
    address caller;
    address otherCaller;

    LossPolicyMock lossPolicy;

    uint16 constant LIQUIDATION_DISCOUNT = 95_00;

    function setUp() public {
        harness = new LiquidationChecksTraitHarness();

        creditFacade = makeAddr("CREDIT_FACADE");
        creditManager = makeAddr("CREDIT_MANAGER");
        creditAccount = makeAddr("CREDIT_ACCOUNT");
        acl = makeAddr("ACL");
        priceFeedStore = makeAddr("PRICE_FEED_STORE");
        caller = makeAddr("CALLER");
        otherCaller = makeAddr("OTHER_CALLER");

        lossPolicy = new LossPolicyMock();

        vm.mockCall(creditFacade, abi.encodeWithSignature("acl()"), abi.encode(acl));
        vm.mockCall(creditFacade, abi.encodeCall(ICreditFacadeV3.lossPolicy, ()), abi.encode(address(lossPolicy)));
        vm.mockCall(creditFacade, abi.encodeCall(ICreditFacadeV3.priceFeedStore, ()), abi.encode(priceFeedStore));
        vm.mockCall(creditFacade, abi.encodeWithSignature("paused()"), abi.encode(false));
        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.fees, ()),
            abi.encode(uint16(0), uint16(0), LIQUIDATION_DISCOUNT, uint16(0), uint16(97_00))
        );
        vm.mockCall(acl, abi.encodeCall(IACL.hasRole, ("EMERGENCY_LIQUIDATOR", caller)), abi.encode(false));
        vm.mockCall(acl, abi.encodeCall(IACL.hasRole, ("EMERGENCY_LIQUIDATOR", otherCaller)), abi.encode(false));
    }

    function _mockCollateralDebtData(CollateralDebtData memory cdd) internal {
        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.calcDebtAndCollateral, (creditAccount, CollateralCalcTask.DEBT_COLLATERAL)),
            abi.encode(cdd)
        );
    }

    function _healthyNoBadDebtCdd() internal pure returns (CollateralDebtData memory cdd) {
        cdd.debt = 100e18;
        cdd.accruedInterest = 0;
        cdd.totalDebtUSD = 100e8;
        cdd.totalValue = 200e18;
        cdd.twvUSD = 150e8;
    }

    function _unhealthyBadDebtCdd() internal pure returns (CollateralDebtData memory cdd) {
        // totalValue * 9500 < (debt + interest) * 10000  =>  50e18 * 9500 < 100e18 * 10000
        cdd.debt = 100e18;
        cdd.accruedInterest = 0;
        cdd.totalDebtUSD = 100e8;
        cdd.totalValue = 50e18;
        cdd.twvUSD = 40e8;
    }

    function _unhealthyNoBadDebtCdd() internal pure returns (CollateralDebtData memory cdd) {
        // underwater on TWV but totalValue covers debt after discount
        cdd.debt = 100e18;
        cdd.accruedInterest = 0;
        cdd.totalDebtUSD = 100e8;
        cdd.totalValue = 120e18;
        cdd.twvUSD = 90e8;
    }

    // ------------------ //
    // cut price updates  //
    // ------------------ //

    /// @notice U:[LCT-1]: `_cutOnDemandPriceUpdates` returns a full copy and empty updates when first call is unrelated
    function test_U_LCT_01_cutOnDemandPriceUpdates_noop_when_no_leading_updates() public {
        MultiCall[] memory calls = new MultiCall[](2);
        calls[0] = MultiCall({
            target: creditFacade, callData: abi.encodeWithSignature("addCollateral(address,uint256)", address(1), 1)
        });
        calls[1] = MultiCall({target: makeAddr("ADAPTER"), callData: hex"dead"});

        (MultiCall[] memory remaining, PriceUpdate[] memory updates) =
            harness.cutOnDemandPriceUpdates(creditFacade, calls);

        assertEq(updates.length, 0, "Unexpected price updates");
        assertEq(remaining.length, 2, "Incorrect remaining length");
        assertEq(remaining[0].target, calls[0].target, "Incorrect remaining[0].target");
        assertEq(remaining[0].callData, calls[0].callData, "Incorrect remaining[0].callData");
        assertEq(remaining[1].target, calls[1].target, "Incorrect remaining[1].target");
        assertEq(remaining[1].callData, calls[1].callData, "Incorrect remaining[1].callData");
    }

    /// @notice U:[LCT-2]: `_cutOnDemandPriceUpdates` strips leading `onDemandPriceUpdates` and returns decoded updates
    function test_U_LCT_02_cutOnDemandPriceUpdates_cuts_leading_updates() public {
        PriceUpdate[] memory expectedUpdates = new PriceUpdate[](2);
        expectedUpdates[0] = PriceUpdate({priceFeed: makeAddr("PF1"), data: hex"01"});
        expectedUpdates[1] = PriceUpdate({priceFeed: makeAddr("PF2"), data: hex"02"});

        MultiCall[] memory calls = new MultiCall[](2);
        calls[0] = MultiCall({
            target: creditFacade,
            callData: abi.encodeCall(ICreditFacadeV3Multicall.onDemandPriceUpdates, (expectedUpdates))
        });
        calls[1] = MultiCall({target: makeAddr("ADAPTER"), callData: hex"abcd"});

        (MultiCall[] memory remaining, PriceUpdate[] memory updates) =
            harness.cutOnDemandPriceUpdates(creditFacade, calls);

        assertEq(updates.length, 2, "Incorrect updates length");
        assertEq(updates[0].priceFeed, expectedUpdates[0].priceFeed, "Incorrect updates[0].priceFeed");
        assertEq(updates[0].data, expectedUpdates[0].data, "Incorrect updates[0].data");
        assertEq(updates[1].priceFeed, expectedUpdates[1].priceFeed, "Incorrect updates[1].priceFeed");
        assertEq(updates[1].data, expectedUpdates[1].data, "Incorrect updates[1].data");

        assertEq(remaining.length, 1, "Incorrect remaining length");
        assertEq(remaining[0].target, calls[1].target, "Incorrect remaining target");
        assertEq(remaining[0].callData, calls[1].callData, "Incorrect remaining callData");
    }

    /// @notice U:[LCT-2A]: `_cutOnDemandPriceUpdates` ignores `onDemandPriceUpdates` not targeting the facade
    function test_U_LCT_02A_cutOnDemandPriceUpdates_ignores_wrong_target() public {
        PriceUpdate[] memory expectedUpdates = new PriceUpdate[](1);
        expectedUpdates[0] = PriceUpdate({priceFeed: makeAddr("PF"), data: hex"01"});

        MultiCall[] memory calls = new MultiCall[](1);
        calls[0] = MultiCall({
            target: makeAddr("NOT_FACADE"),
            callData: abi.encodeCall(ICreditFacadeV3Multicall.onDemandPriceUpdates, (expectedUpdates))
        });

        (MultiCall[] memory remaining, PriceUpdate[] memory updates) =
            harness.cutOnDemandPriceUpdates(creditFacade, calls);

        assertEq(updates.length, 0, "Unexpected price updates");
        assertEq(remaining.length, 1, "Incorrect remaining length");
    }

    /// @notice U:[LCT-2B]: `_cutOnDemandPriceUpdates` handles empty calls
    function test_U_LCT_02B_cutOnDemandPriceUpdates_handles_empty_calls() public view {
        MultiCall[] memory calls = new MultiCall[](0);
        (MultiCall[] memory remaining, PriceUpdate[] memory updates) =
            harness.cutOnDemandPriceUpdates(creditFacade, calls);

        assertEq(updates.length, 0, "Unexpected price updates");
        assertEq(remaining.length, 0, "Incorrect remaining length");
    }

    // ------------------ //
    // apply price updates //
    // ------------------ //

    /// @notice U:[LCT-3]: `_applyPriceUpdates` is a no-op for an empty array
    function test_U_LCT_03_applyPriceUpdates_noop_when_empty() public {
        PriceUpdate[] memory updates = new PriceUpdate[](0);
        // Would revert if priceFeedStore() were called
        vm.mockCallRevert(creditFacade, abi.encodeCall(ICreditFacadeV3.priceFeedStore, ()), "SHOULD_NOT_CALL");
        harness.applyPriceUpdates(creditFacade, updates);
    }

    /// @notice U:[LCT-4]: `_applyPriceUpdates` forwards updates to the facade price feed store
    function test_U_LCT_04_applyPriceUpdates_forwards_to_store() public {
        PriceUpdate[] memory updates = new PriceUpdate[](1);
        updates[0] = PriceUpdate({priceFeed: makeAddr("PF"), data: hex"aa"});

        vm.mockCall(priceFeedStore, abi.encodeCall(IPriceFeedStore.updatePrices, (updates)), abi.encode());
        vm.expectCall(priceFeedStore, abi.encodeCall(IPriceFeedStore.updatePrices, (updates)));
        harness.applyPriceUpdates(creditFacade, updates);
    }

    // ------------------ //
    // hasBadDebt         //
    // ------------------ //

    /// @notice U:[LCT-5]: `_hasBadDebt` matches the CreditFacade formula
    function test_U_LCT_05_hasBadDebt_matches_formula() public view {
        CollateralDebtData memory bad = _unhealthyBadDebtCdd();
        assertTrue(harness.hasBadDebt(creditManager, bad), "Expected bad debt");

        CollateralDebtData memory ok = _unhealthyNoBadDebtCdd();
        assertFalse(harness.hasBadDebt(creditManager, ok), "Expected no bad debt");

        // boundary: equality is not bad debt
        CollateralDebtData memory boundary;
        boundary.debt = 95e18;
        boundary.accruedInterest = 0;
        boundary.totalValue = 100e18;
        // 100e18 * 9500 == 95e18 * 10000
        assertFalse(harness.hasBadDebt(creditManager, boundary), "Equality should not be bad debt");
        assertEq(
            boundary.totalValue * LIQUIDATION_DISCOUNT,
            (boundary.debt + boundary.accruedInterest) * PERCENTAGE_FACTOR,
            "Sanity: boundary equality"
        );
    }

    // ------------------ //
    // pause / emergency  //
    // ------------------ //

    /// @notice U:[LCT-6]: `_revertIfNotAllowedToLiquidate` reverts when paused and caller is not emergency liquidator
    function test_U_LCT_06_reverts_when_paused_without_emergency_role() public {
        vm.mockCall(creditFacade, abi.encodeWithSignature("paused()"), abi.encode(true));
        _mockCollateralDebtData(_healthyNoBadDebtCdd());

        vm.expectRevert(LiquidationChecksTrait.CallerNotEmergencyLiquidatorException.selector);
        harness.revertIfNotAllowedToLiquidate(creditFacade, creditManager, creditAccount, caller, "");
    }

    /// @notice U:[LCT-7]: `_revertIfNotAllowedToLiquidate` allows paused liquidations for emergency liquidators
    function test_U_LCT_07_allows_paused_for_emergency_liquidator() public {
        vm.mockCall(creditFacade, abi.encodeWithSignature("paused()"), abi.encode(true));
        vm.mockCall(acl, abi.encodeCall(IACL.hasRole, ("EMERGENCY_LIQUIDATOR", caller)), abi.encode(true));
        _mockCollateralDebtData(_healthyNoBadDebtCdd());

        harness.revertIfNotAllowedToLiquidate(creditFacade, creditManager, creditAccount, caller, "");
    }

    // ------------------ //
    // loss policy        //
    // ------------------ //

    /// @notice U:[LCT-8]: skips loss-policy check when account is healthy
    function test_U_LCT_08_skips_loss_policy_when_healthy() public {
        lossPolicy.setisLiquidatableWithLossResult(false);
        _mockCollateralDebtData(_healthyNoBadDebtCdd());

        // Would revert if loss policy were consulted and returned false
        harness.revertIfNotAllowedToLiquidate(creditFacade, creditManager, creditAccount, caller, "");
    }

    /// @notice U:[LCT-9]: skips loss-policy check when unhealthy but without bad debt
    function test_U_LCT_09_skips_loss_policy_when_unhealthy_without_bad_debt() public {
        lossPolicy.setisLiquidatableWithLossResult(false);
        _mockCollateralDebtData(_unhealthyNoBadDebtCdd());

        harness.revertIfNotAllowedToLiquidate(creditFacade, creditManager, creditAccount, caller, "");
    }

    /// @notice U:[LCT-10]: reverts when unhealthy with bad debt and loss policy rejects the caller
    function test_U_LCT_10_reverts_when_loss_policy_rejects_bad_debt_liquidation() public {
        lossPolicy.setisLiquidatableWithLossResult(false);
        _mockCollateralDebtData(_unhealthyBadDebtCdd());

        vm.expectRevert(CreditAccountNotLiquidatableWithLossException.selector);
        harness.revertIfNotAllowedToLiquidate(creditFacade, creditManager, creditAccount, caller, hex"abcd");
    }

    /// @notice U:[LCT-11]: allows bad-debt liquidation when loss policy accepts the caller
    function test_U_LCT_11_allows_when_loss_policy_accepts_bad_debt_liquidation() public {
        lossPolicy.setisLiquidatableWithLossResult(true);
        bytes memory lossPolicyData = hex"abcd";
        CollateralDebtData memory cdd = _unhealthyBadDebtCdd();
        _mockCollateralDebtData(cdd);

        ILossPolicy.Params memory expectedParams =
            ILossPolicy.Params({totalDebtUSD: cdd.totalDebtUSD, twvUSD: cdd.twvUSD, extraData: lossPolicyData});

        vm.expectCall(
            address(lossPolicy),
            abi.encodeCall(ILossPolicy.isLiquidatableWithLoss, (creditAccount, caller, expectedParams))
        );
        harness.revertIfNotAllowedToLiquidate(creditFacade, creditManager, creditAccount, caller, lossPolicyData);
    }

    /// @notice U:[LCT-12]: loss-policy check uses the provided caller, not a hardcoded address
    function test_U_LCT_12_loss_policy_uses_provided_caller() public {
        lossPolicy.setisLiquidatableWithLossResult(true);
        bytes memory lossPolicyData = "";
        CollateralDebtData memory cdd = _unhealthyBadDebtCdd();
        _mockCollateralDebtData(cdd);

        ILossPolicy.Params memory expectedParams =
            ILossPolicy.Params({totalDebtUSD: cdd.totalDebtUSD, twvUSD: cdd.twvUSD, extraData: lossPolicyData});

        vm.expectCall(
            address(lossPolicy),
            abi.encodeCall(ILossPolicy.isLiquidatableWithLoss, (creditAccount, otherCaller, expectedParams))
        );
        harness.revertIfNotAllowedToLiquidate(creditFacade, creditManager, creditAccount, otherCaller, lossPolicyData);
    }
}
