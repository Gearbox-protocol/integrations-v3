// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {CollateralDebtData} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {PriceOracleMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceOracleMock.sol";

import {IERC4626Adapter} from "../../../../integrations/erc4626/interfaces/IERC4626Adapter.sol";
import {
    ISecuritizeRedemptionGateway
} from "../../../../integrations/securitize/interfaces/ISecuritizeRedemptionGateway.sol";
import {
    ISecuritizeRedemptionGatewayAdapter
} from "../../../../integrations/securitize/interfaces/ISecuritizeRedemptionGatewayAdapter.sol";
import {SecuritizeRedeemer} from "../../../../integrations/securitize/SecuritizeRedeemer.sol";
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

    function calcCollateralAndLiquidityValues(
        address creditAccount,
        address creditManager,
        address underlying,
        address redemptionGateway,
        address[] memory redeemers,
        uint16 liquidationDiscount
    ) external view returns (uint256, uint256) {
        return _calcCollateralAndLiquidityValues(
            creditAccount, creditManager, underlying, redemptionGateway, redeemers, liquidationDiscount
        );
    }

    function getLiquidationCalls(
        address creditAccount,
        address creditManager,
        address creditFacade,
        address redemptionGateway,
        address underlying,
        uint256 underlyingAmount,
        address[] memory redeemers,
        address to
    ) external view returns (MultiCall[] memory) {
        return _getLiquidationCalls(
            creditAccount, creditManager, creditFacade, redemptionGateway, underlying, underlyingAmount, redeemers, to
        );
    }
}

/// @title SecuritizeLiquidator unit test
/// @notice U:[SL]: Unit tests for SecuritizeLiquidator
contract SecuritizeLiquidatorUnitTest is Test {
    SecuritizeLiquidatorHarness liquidator;
    PriceOracleMock priceOracle;

    address creditManager;
    address creditFacade;
    address creditAccount;
    address rwaFactory;
    address gateway;
    address gatewayAdapter;
    address underlyingAdapter;
    address liquidatorEOA;

    ERC20Mock underlying;
    ERC20Mock unwrappedUnderlying;
    ERC20Mock stableCoinToken;
    ERC20Mock dsToken;

    address redeemer;

    uint16 constant LIQUIDATION_DISCOUNT = 95_00;
    uint16 constant LIQUIDATION_DISCOUNT_EXPIRED = 97_00;

    function setUp() public {
        creditManager = makeAddr("CREDIT_MANAGER");
        creditFacade = makeAddr("CREDIT_FACADE");
        creditAccount = makeAddr("CREDIT_ACCOUNT");
        rwaFactory = makeAddr("RWA_FACTORY");
        gateway = makeAddr("GATEWAY");
        gatewayAdapter = makeAddr("GATEWAY_ADAPTER");
        underlyingAdapter = makeAddr("UNDERLYING_ADAPTER");
        liquidatorEOA = makeAddr("LIQUIDATOR_EOA");
        redeemer = makeAddr("REDEEMER");

        liquidator = new SecuritizeLiquidatorHarness(rwaFactory);
        priceOracle = new PriceOracleMock();

        underlying = new ERC20Mock("sUSDS", "sUSDS", 18);
        unwrappedUnderlying = new ERC20Mock("USDS", "USDS", 18);
        stableCoinToken = new ERC20Mock("USDC", "USDC", 18);
        dsToken = new ERC20Mock("DS", "DS", 18);

        priceOracle.setPrice(address(underlying), 1e8);
        priceOracle.setPrice(address(unwrappedUnderlying), 1e8);
        priceOracle.setPrice(address(stableCoinToken), 1e8);
        priceOracle.setPrice(address(dsToken), 1e8);

        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.fees, ()),
            abi.encode(uint16(0), uint16(0), LIQUIDATION_DISCOUNT, uint16(0), LIQUIDATION_DISCOUNT_EXPIRED)
        );
        vm.mockCall(creditManager, abi.encodeCall(ICreditManagerV3.priceOracle, ()), abi.encode(address(priceOracle)));
        vm.mockCall(
            creditManager, abi.encodeCall(ICreditManagerV3.contractToAdapter, (gateway)), abi.encode(gatewayAdapter)
        );
        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.contractToAdapter, (address(underlying))),
            abi.encode(underlyingAdapter)
        );
        vm.mockCall(address(underlying), abi.encodeCall(IERC4626.asset, ()), abi.encode(address(unwrappedUnderlying)));
        vm.mockCall(gateway, abi.encodeCall(ISecuritizeRedemptionGateway.dsToken, ()), abi.encode(address(dsToken)));
    }

    function _setStableCoin(address token) internal {
        vm.mockCall(gateway, abi.encodeCall(ISecuritizeRedemptionGateway.stableCoinToken, ()), abi.encode(token));
    }

    /// @notice U:[SL-1]: Constructor works as expected
    function test_U_SL_01_constructor_works() public view {
        assertEq(liquidator.contractType(), "RWA_LIQUIDATOR::SECURITIZE", "Incorrect contract type");
        assertEq(liquidator.version(), 3_12, "Incorrect version");
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

    /// @notice U:[SL-4]: When stableCoin == unwrapped, CA stable is liquidity only and is not converted
    function test_U_SL_04_equal_tokens_use_raw_balances() public {
        _setStableCoin(address(unwrappedUnderlying));

        unwrappedUnderlying.mint(redeemer, 100e18);
        vm.mockCall(redeemer, abi.encodeCall(SecuritizeRedeemer.getCurrentRedemptionValue, ()), abi.encode(80e18));

        unwrappedUnderlying.mint(creditAccount, 50e18);
        underlying.mint(creditAccount, 10e18);
        dsToken.mint(creditAccount, 30e18);

        address[] memory redeemers = new address[](1);
        redeemers[0] = redeemer;

        (uint256 collateralValue, uint256 liquidityAmount) = liquidator.calcCollateralAndLiquidityValues(
            creditAccount, creditManager, address(underlying), gateway, redeemers, LIQUIDATION_DISCOUNT
        );

        // Redeemer max(100, 80) + converted dsToken; CA unwrapped is not bought out.
        assertEq(collateralValue, 130e18, "Incorrect collateral value");
        // Redeemer 100 + CA unwrapped 50 + CA underlying 10, then discounted.
        assertEq(liquidityAmount, 152e18, "Incorrect liquidity amount");
    }

    /// @notice U:[SL-5]: When stableCoin != unwrapped, stable is collateral and liquidity, converted to underlying
    function test_U_SL_05_unequal_tokens_convert_stablecoin_and_include_ca_balance_in_collateral() public {
        _setStableCoin(address(stableCoinToken));
        priceOracle.setPrice(address(stableCoinToken), 2e8);

        stableCoinToken.mint(redeemer, 100e18);
        vm.mockCall(redeemer, abi.encodeCall(SecuritizeRedeemer.getCurrentRedemptionValue, ()), abi.encode(80e18));

        stableCoinToken.mint(creditAccount, 50e18);
        unwrappedUnderlying.mint(creditAccount, 20e18);
        underlying.mint(creditAccount, 10e18);
        dsToken.mint(creditAccount, 30e18);

        address[] memory redeemers = new address[](1);
        redeemers[0] = redeemer;

        (uint256 collateralValue, uint256 liquidityAmount) = liquidator.calcCollateralAndLiquidityValues(
            creditAccount, creditManager, address(underlying), gateway, redeemers, LIQUIDATION_DISCOUNT
        );

        // (redeemer 100 + CA stable 50) converted 2:1 → 300, plus dsToken 30.
        assertEq(collateralValue, 330e18, "Incorrect collateral value");
        // Converted stable liquidity 300 + unwrapped 20 + underlying 10, then discounted.
        assertEq(liquidityAmount, 313.5e18, "Incorrect liquidity amount");
    }

    /// @notice U:[SL-6]: Redeemer transfer path withdraws distinct stablecoin and wraps leftover unwrapped
    function test_U_SL_06_unequal_tokens_withdraw_stablecoin_and_wrap_unwrapped() public {
        _setStableCoin(address(stableCoinToken));

        stableCoinToken.mint(creditAccount, 40e18);
        unwrappedUnderlying.mint(creditAccount, 15e18);
        dsToken.mint(creditAccount, 5e18);

        address[] memory redeemers = new address[](1);
        redeemers[0] = redeemer;

        MultiCall[] memory calls = liquidator.getLiquidationCalls(
            creditAccount, creditManager, creditFacade, gateway, address(underlying), 1e18, redeemers, liquidatorEOA
        );

        assertEq(calls.length, 5, "Unexpected number of calls");
        assertEq(calls[0].target, gatewayAdapter, "Expected transferRedeemer");
        assertEq(
            calls[0].callData,
            abi.encodeCall(ISecuritizeRedemptionGatewayAdapter.transferRedeemer, (redeemer, liquidatorEOA)),
            "Incorrect transferRedeemer calldata"
        );
        assertEq(
            calls[1].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (address(underlying), 1e18)),
            "Incorrect addCollateral calldata"
        );
        assertEq(
            calls[2].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.withdrawCollateral, (address(dsToken), 5e18, liquidatorEOA)),
            "Incorrect dsToken withdrawal"
        );
        assertEq(
            calls[3].callData,
            abi.encodeCall(
                ICreditFacadeV3Multicall.withdrawCollateral, (address(stableCoinToken), 40e18, liquidatorEOA)
            ),
            "Incorrect stablecoin withdrawal"
        );
        assertEq(calls[4].target, underlyingAdapter, "Expected wrap of unwrapped underlying");
        assertEq(calls[4].callData, abi.encodeCall(IERC4626Adapter.depositDiff, (1)), "Incorrect depositDiff calldata");
    }

    /// @notice U:[SL-7]: When stableCoin == unwrapped, leftover unwrapped is wrapped and not withdrawn
    function test_U_SL_07_equal_tokens_wrap_unwrapped_without_stablecoin_withdrawal() public {
        _setStableCoin(address(unwrappedUnderlying));

        unwrappedUnderlying.mint(creditAccount, 15e18);

        address[] memory redeemers = new address[](0);

        MultiCall[] memory calls = liquidator.getLiquidationCalls(
            creditAccount, creditManager, creditFacade, gateway, address(underlying), 1e18, redeemers, liquidatorEOA
        );

        assertEq(calls.length, 2, "Unexpected number of calls");
        assertEq(
            calls[0].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (address(underlying), 1e18)),
            "Incorrect addCollateral calldata"
        );
        assertEq(calls[1].target, underlyingAdapter, "Expected wrap of unwrapped underlying");
        assertEq(calls[1].callData, abi.encodeCall(IERC4626Adapter.depositDiff, (1)), "Incorrect depositDiff calldata");
    }
}
