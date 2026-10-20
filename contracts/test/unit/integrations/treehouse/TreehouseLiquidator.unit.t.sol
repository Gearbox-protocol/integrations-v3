// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {IACL} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IACL.sol";
import {IPriceFeedStore, PriceUpdate} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeedStore.sol";
import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
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
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {TreehouseLiquidator} from "../../../../integrations/treehouse/TreehouseLiquidator.sol";
import {ITreehouseLiquidator} from "../../../../integrations/treehouse/interfaces/ITreehouseLiquidator.sol";
import {
    ITreehouseRedemptionGateway
} from "../../../../integrations/treehouse/interfaces/ITreehouseRedemptionGateway.sol";
import {LiquidationChecksTrait} from "../../../../integrations/common/LiquidationChecksTrait.sol";

/// @dev Credit facade stand-in that records the liquidation call and observes transfer unlock
contract CreditFacadeLiquidationMock {
    TreehouseLiquidator public liquidator;
    address public expectedAccount;

    address public lastCreditAccount;
    address public lastTo;
    bytes public lastLossPolicyData;
    uint256 public lastCallsLength;
    bool public sawTransferAllowed;

    function setLiquidator(TreehouseLiquidator liquidator_, address expectedAccount_) external {
        liquidator = liquidator_;
        expectedAccount = expectedAccount_;
    }

    function liquidateCreditAccount(
        address creditAccount,
        address to,
        MultiCall[] calldata calls,
        bytes memory lossPolicyData
    ) external {
        lastCreditAccount = creditAccount;
        lastTo = to;
        lastCallsLength = calls.length;
        lastLossPolicyData = lossPolicyData;
        sawTransferAllowed = liquidator.isTransferAllowed(expectedAccount);
    }

    // Used by LiquidationChecksTrait / Pausable cast
    function paused() external pure returns (bool) {
        return false;
    }

    function acl() external view returns (address) {
        return address(0);
    }

    function lossPolicy() external view returns (address) {
        return address(0);
    }

    function priceFeedStore() external view returns (address) {
        return address(0);
    }
}

/// @title TreehouseLiquidator unit test
/// @notice U:[TH-L]: Unit tests for TreehouseLiquidator
contract TreehouseLiquidatorUnitTest is Test {
    TreehouseLiquidator liquidator;
    CreditFacadeLiquidationMock facadeMock;

    address creditManager;
    address creditAccount;
    address gateway;
    address gatewayAdapter;
    address acl;
    address priceFeedStore;
    address liquidatorEOA;

    LossPolicyMock lossPolicy;
    ERC20Mock collateralToken;

    uint16 constant LIQUIDATION_DISCOUNT = 95_00;

    function setUp() public {
        liquidator = new TreehouseLiquidator();
        facadeMock = new CreditFacadeLiquidationMock();

        creditManager = makeAddr("CREDIT_MANAGER");
        creditAccount = makeAddr("CREDIT_ACCOUNT");
        gateway = makeAddr("GATEWAY");
        gatewayAdapter = makeAddr("GATEWAY_ADAPTER");
        acl = makeAddr("ACL");
        priceFeedStore = makeAddr("PRICE_FEED_STORE");
        liquidatorEOA = makeAddr("LIQUIDATOR_EOA");

        lossPolicy = new LossPolicyMock();
        collateralToken = new ERC20Mock("USDC", "USDC", 6);

        facadeMock.setLiquidator(liquidator, creditAccount);

        vm.mockCall(creditAccount, abi.encodeCall(ICreditAccountV3.creditManager, ()), abi.encode(creditManager));
        vm.mockCall(creditManager, abi.encodeCall(ICreditManagerV3.creditFacade, ()), abi.encode(address(facadeMock)));
        vm.mockCall(
            creditManager, abi.encodeCall(ICreditManagerV3.contractToAdapter, (gateway)), abi.encode(gatewayAdapter)
        );
        vm.mockCall(
            gateway, abi.encodeCall(ITreehouseRedemptionGateway.transferMaster, ()), abi.encode(address(liquidator))
        );

        // LiquidationChecksTrait reads these from the facade address
        vm.mockCall(address(facadeMock), abi.encodeWithSignature("acl()"), abi.encode(acl));
        vm.mockCall(
            address(facadeMock), abi.encodeCall(ICreditFacadeV3.lossPolicy, ()), abi.encode(address(lossPolicy))
        );
        vm.mockCall(address(facadeMock), abi.encodeCall(ICreditFacadeV3.priceFeedStore, ()), abi.encode(priceFeedStore));
        vm.mockCall(address(facadeMock), abi.encodeWithSignature("paused()"), abi.encode(false));
        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.fees, ()),
            abi.encode(uint16(0), uint16(0), LIQUIDATION_DISCOUNT, uint16(0), uint16(97_00))
        );
        vm.mockCall(acl, abi.encodeCall(IACL.hasRole, ("EMERGENCY_LIQUIDATOR", liquidatorEOA)), abi.encode(false));

        CollateralDebtData memory cdd;
        cdd.debt = 100e18;
        cdd.totalDebtUSD = 100e8;
        cdd.totalValue = 200e18;
        cdd.twvUSD = 150e8;
        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.calcDebtAndCollateral, (creditAccount, CollateralCalcTask.DEBT_COLLATERAL)),
            abi.encode(cdd)
        );
    }

    /// @notice U:[TH-L-1]: Metadata works
    function test_U_TH_L_01_metadata() public view {
        assertEq(liquidator.contractType(), "RWA_LIQUIDATOR::TREEHOUSE", "Incorrect contract type");
        assertEq(liquidator.version(), 3_10, "Incorrect version");
        assertEq(liquidator.transferableRedeemerOwner(), address(0), "Should start locked");
    }

    /// @notice U:[TH-L-2]: Reverts when gateway transfer master is not this liquidator
    function test_U_TH_L_02_reverts_for_invalid_transfer_master() public {
        vm.mockCall(
            gateway, abi.encodeCall(ITreehouseRedemptionGateway.transferMaster, ()), abi.encode(makeAddr("OTHER"))
        );

        MultiCall[] memory calls = new MultiCall[](0);
        vm.prank(liquidatorEOA);
        vm.expectRevert(ITreehouseLiquidator.NotValidGatewayException.selector);
        liquidator.liquidateWithRedeemerTransfers(creditAccount, gateway, calls, "");
    }

    /// @notice U:[TH-L-3]: Reverts when gateway is not registered on the credit manager
    function test_U_TH_L_03_reverts_for_unregistered_gateway() public {
        vm.mockCall(
            creditManager, abi.encodeCall(ICreditManagerV3.contractToAdapter, (gateway)), abi.encode(address(0))
        );

        MultiCall[] memory calls = new MultiCall[](0);
        vm.prank(liquidatorEOA);
        vm.expectRevert(ITreehouseLiquidator.NotValidGatewayException.selector);
        liquidator.liquidateWithRedeemerTransfers(creditAccount, gateway, calls, "");
    }

    /// @notice U:[TH-L-4]: Reverts when facade is paused and caller is not an emergency liquidator
    function test_U_TH_L_04_reverts_when_paused_without_emergency_role() public {
        vm.mockCall(address(facadeMock), abi.encodeWithSignature("paused()"), abi.encode(true));

        MultiCall[] memory calls = new MultiCall[](0);
        vm.prank(liquidatorEOA);
        vm.expectRevert(LiquidationChecksTrait.CallerNotEmergencyLiquidatorException.selector);
        liquidator.liquidateWithRedeemerTransfers(creditAccount, gateway, calls, "");
    }

    /// @notice U:[TH-L-5]: Reverts when loss policy rejects a bad-debt liquidation for the caller
    function test_U_TH_L_05_reverts_when_loss_policy_rejects() public {
        lossPolicy.setisLiquidatableWithLossResult(false);

        CollateralDebtData memory cdd;
        cdd.debt = 100e18;
        cdd.totalDebtUSD = 100e8;
        cdd.totalValue = 50e18;
        cdd.twvUSD = 40e8;
        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.calcDebtAndCollateral, (creditAccount, CollateralCalcTask.DEBT_COLLATERAL)),
            abi.encode(cdd)
        );

        MultiCall[] memory calls = new MultiCall[](0);
        vm.prank(liquidatorEOA);
        vm.expectRevert(CreditAccountNotLiquidatableWithLossException.selector);
        liquidator.liquidateWithRedeemerTransfers(creditAccount, gateway, calls, "");
    }

    /// @notice U:[TH-L-6]: Applies leading price updates, strips them from facade calls, unlocks during call
    function test_U_TH_L_06_cuts_applies_price_updates_and_unlocks() public {
        PriceUpdate[] memory updates = new PriceUpdate[](1);
        updates[0] = PriceUpdate({priceFeed: makeAddr("PF"), data: hex"01"});

        MultiCall[] memory calls = new MultiCall[](2);
        calls[0] = MultiCall({
            target: address(facadeMock),
            callData: abi.encodeCall(ICreditFacadeV3Multicall.onDemandPriceUpdates, (updates))
        });
        calls[1] = MultiCall({target: gatewayAdapter, callData: hex"abcd"});

        vm.mockCall(priceFeedStore, abi.encodeCall(IPriceFeedStore.updatePrices, (updates)), abi.encode());
        vm.expectCall(priceFeedStore, abi.encodeCall(IPriceFeedStore.updatePrices, (updates)));

        bytes memory lossPolicyData = hex"aa";
        vm.prank(liquidatorEOA);
        liquidator.liquidateWithRedeemerTransfers(creditAccount, gateway, calls, lossPolicyData);

        assertEq(facadeMock.lastCreditAccount(), creditAccount, "Incorrect credit account");
        assertEq(facadeMock.lastTo(), liquidatorEOA, "Incorrect `to`");
        assertEq(facadeMock.lastCallsLength(), 1, "Price updates should be stripped");
        assertEq(facadeMock.lastLossPolicyData(), lossPolicyData, "Incorrect loss policy data");
        assertTrue(facadeMock.sawTransferAllowed(), "Transfers should be unlocked during facade call");
        assertEq(liquidator.transferableRedeemerOwner(), address(0), "Should re-lock after liquidation");
        assertFalse(liquidator.isTransferAllowed(creditAccount), "Should be locked after liquidation");
    }

    /// @notice U:[TH-L-7]: Forwards `addCollateral` tokens from the caller to this contract and approves the CM
    function test_U_TH_L_07_forwards_collateral() public {
        uint256 amount = 1_000e6;
        collateralToken.mint(liquidatorEOA, amount);

        vm.prank(liquidatorEOA);
        collateralToken.approve(address(liquidator), amount);

        MultiCall[] memory calls = new MultiCall[](1);
        calls[0] = MultiCall({
            target: address(facadeMock),
            callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (address(collateralToken), amount))
        });

        vm.prank(liquidatorEOA);
        liquidator.liquidateWithRedeemerTransfers(creditAccount, gateway, calls, "");

        assertEq(collateralToken.balanceOf(address(liquidator)), amount, "Tokens not forwarded to liquidator");
        assertEq(collateralToken.allowance(address(liquidator), creditManager), amount, "Missing CM allowance");
        assertEq(collateralToken.balanceOf(liquidatorEOA), 0, "Caller should have been drained");
    }
}
