// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {CollateralDebtData} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {SecuritizeLiquidator} from "../../../../integrations/securitize/SecuritizeLiquidator.sol";

contract SecuritizeLiquidatorHarness is SecuritizeLiquidator {
    constructor(address securitizeRWAFactory) SecuritizeLiquidator(securitizeRWAFactory) {}

    function getLiquidationDiscount(address creditManager, CollateralDebtData memory cdd)
        external
        view
        returns (uint16)
    {
        return _getLiquidationDiscount(creditManager, cdd);
    }
}

/// @title SecuritizeLiquidator unit test
/// @notice U:[SL]: Unit tests for SecuritizeLiquidator
contract SecuritizeLiquidatorUnitTest is Test {
    SecuritizeLiquidatorHarness liquidator;
    address creditManager;
    address rwaFactory;

    uint16 constant LIQUIDATION_DISCOUNT = 95_00;
    uint16 constant LIQUIDATION_DISCOUNT_EXPIRED = 97_00;

    function setUp() public {
        creditManager = makeAddr("CREDIT_MANAGER");
        rwaFactory = makeAddr("RWA_FACTORY");
        liquidator = new SecuritizeLiquidatorHarness(rwaFactory);

        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.fees, ()),
            abi.encode(uint16(0), uint16(0), LIQUIDATION_DISCOUNT, uint16(0), LIQUIDATION_DISCOUNT_EXPIRED)
        );
    }

    /// @notice U:[SL-1]: Constructor works as expected
    function test_U_SL_01_constructor_works() public view {
        assertEq(liquidator.contractType(), "RWA_LIQUIDATOR::SECURITIZE", "Incorrect contract type");
        assertEq(liquidator.version(), 3_11, "Incorrect version");
        assertEq(liquidator.securitizeRWAFactory(), rwaFactory, "Incorrect factory");
    }

    /// @notice U:[SL-2]: Uses normal liquidation discount when account is underwater
    function test_U_SL_02_uses_normal_discount_when_underwater() public view {
        CollateralDebtData memory cdd;
        cdd.totalDebtUSD = 101;
        cdd.twvUSD = 100;

        assertEq(
            liquidator.getLiquidationDiscount(creditManager, cdd),
            LIQUIDATION_DISCOUNT,
            "Should use normal liquidation discount"
        );
    }

    /// @notice U:[SL-3]: Uses expired liquidation discount when account is not underwater
    function test_U_SL_03_uses_expired_discount_when_not_underwater() public view {
        CollateralDebtData memory cdd;
        cdd.totalDebtUSD = 100;
        cdd.twvUSD = 100;

        assertEq(
            liquidator.getLiquidationDiscount(creditManager, cdd),
            LIQUIDATION_DISCOUNT_EXPIRED,
            "Should use expired liquidation discount when debt equals TWV"
        );

        cdd.totalDebtUSD = 99;
        assertEq(
            liquidator.getLiquidationDiscount(creditManager, cdd),
            LIQUIDATION_DISCOUNT_EXPIRED,
            "Should use expired liquidation discount when debt is below TWV"
        );
    }
}
