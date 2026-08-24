// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISecuritizeLiquidator} from "./interfaces/ISecuritizeLiquidator.sol";

import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {
    ICreditManagerV3,
    CollateralDebtData,
    CollateralCalcTask
} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditFacadeV3, MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {IPriceFeedStore, PriceUpdate} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeedStore.sol";
import {IPriceOracleV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";
import {CreditLogic} from "@gearbox-protocol/core-v3/contracts/libraries/CreditLogic.sol";

import {IERC4626Adapter} from "../erc4626/interfaces/IERC4626Adapter.sol";

import {ISecuritizeRWAFactory} from "./interfaces/external/ISecuritizeRWAFactory.sol";
import {ISecuritizeRedemptionGateway} from "./interfaces/ISecuritizeRedemptionGateway.sol";
import {ISecuritizeRedemptionGatewayAdapter} from "./interfaces/ISecuritizeRedemptionGatewayAdapter.sol";
import {ISecuritizeWhitelister} from "./interfaces/external/ISecuritizeWhitelister.sol";
import {ISecuritizeGatewayTransferMaster} from "./interfaces/ISecuritizeGatewayTransferMaster.sol";
import {SecuritizeRedeemer} from "./SecuritizeRedeemer.sol";

import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

contract SecuritizeLiquidator is ISecuritizeLiquidator {
    using SafeERC20 for IERC20;
    using CreditLogic for CollateralDebtData;

    bytes32 public constant override contractType = "RWA_LIQUIDATOR::SECURITIZE";
    uint256 public constant override version = 3_12;

    address public override transferableRedeemerOwner;

    address public immutable securitizeRWAFactory;

    constructor(address _securitizeRWAFactory) {
        securitizeRWAFactory = _securitizeRWAFactory;
    }

    function liquidatePendingRedemption(
        address creditAccount,
        address redemptionGateway,
        PriceUpdate[] memory priceUpdates,
        bytes memory lossPolicyData
    ) external {
        if (!ISecuritizeRWAFactory(securitizeRWAFactory).isCreditAccount(creditAccount)) {
            revert UnknownCreditAccountException();
        }

        if (ISecuritizeRedemptionGateway(redemptionGateway).transferMaster() != address(this)) {
            revert NotValidGatewayException();
        }

        address creditManager = ICreditAccountV3(creditAccount).creditManager();

        if (ICreditManagerV3(creditManager).contractToAdapter(redemptionGateway) == address(0)) {
            revert NotValidGatewayException();
        }

        address creditFacade = ICreditManagerV3(creditManager).creditFacade();

        _applyPriceUpdates(creditFacade, priceUpdates);

        address underlying = ICreditManagerV3(creditManager).underlying();

        address[] memory redeemers =
            ISecuritizeRedemptionGateway(redemptionGateway).getUnclaimedRedeemers(creditAccount);

        uint256 underlyingAmount;

        {
            CollateralDebtData memory cdd = ICreditManagerV3(creditManager)
                .calcDebtAndCollateral(creditAccount, CollateralCalcTask.DEBT_COLLATERAL);

            uint16 liquidationDiscount = _getLiquidationDiscount(creditManager, cdd);

            (uint256 collateralValue, uint256 liquidityAmount) = _calcCollateralAndLiquidityValues(
                creditAccount, creditManager, underlying, redemptionGateway, redeemers, liquidationDiscount
            );

            underlyingAmount = collateralValue * liquidationDiscount / PERCENTAGE_FACTOR;

            if (liquidityAmount >= cdd.calcTotalDebt()) {
                revert AccountHasSufficientLiquidityException();
            }
        }

        MultiCall[] memory calls = _getLiquidationCalls(
            creditAccount,
            creditManager,
            creditFacade,
            redemptionGateway,
            underlying,
            underlyingAmount,
            redeemers,
            msg.sender
        );

        _transferAndWrapStablecoin(underlying, underlyingAmount);
        IERC20(underlying).forceApprove(creditManager, underlyingAmount);

        transferableRedeemerOwner = creditAccount;
        ICreditFacadeV3(creditFacade).liquidateCreditAccount(creditAccount, creditAccount, calls, lossPolicyData);
        transferableRedeemerOwner = address(0);
    }

    function isTransferAllowed(address redeemerOwner) external view override returns (bool) {
        return redeemerOwner == transferableRedeemerOwner;
    }

    /// @dev Calculates the collateral and liquidity values for the liquidation
    /// @dev There are assumed to be at most 5 tokens on the Credit Account:
    ///      - underlying
    ///      - unwrapped underlying
    ///      - stablecoin used as a base asset for dsToken subscription / redemption
    ///      - dsToken
    ///      - redemption phantom token
    ///      It is also possible for the stablecoin and unwrapped underlying to be the same token.
    /// @dev The rules for calculating the values is as follows:
    ///      - Collateral value includes value of all redeemers, the dsToken, and the stableCoinToken if it is not equal
    ///        to unwrapped underlying
    ///      - Liquidity value includes all wrapped and unwrapped underlying, as well as the stableCoinToken both on the account
    ///        and on redeemers. Unwrapped underlying is 1:1 with underlying, so those balances are used as-is. When
    ///        stableCoinToken differs, its amounts are converted to underlying. Liquidity only determines whether the
    ///        account can be liquidated without redeemer transfers, so the differing stableCoinToken is still included,
    ///        as it assumed that it is easily convertible to unwrapped underlying.
    function _calcCollateralAndLiquidityValues(
        address creditAccount,
        address creditManager,
        address underlying,
        address redemptionGateway,
        address[] memory redeemers,
        uint16 liquidationDiscount
    ) internal view returns (uint256 collateralValue, uint256 liquidityAmount) {
        address stableCoinToken = ISecuritizeRedemptionGateway(redemptionGateway).stableCoinToken();
        address unwrappedUnderlying = IERC4626(underlying).asset();
        address dsToken = ISecuritizeRedemptionGateway(redemptionGateway).dsToken();

        for (uint256 i = 0; i < redeemers.length; i++) {
            uint256 stablecoinAmount = IERC20(stableCoinToken).balanceOf(redeemers[i]);
            uint256 redemptionValue = SecuritizeRedeemer(redeemers[i]).getCurrentRedemptionValue();

            collateralValue += stablecoinAmount > redemptionValue ? stablecoinAmount : redemptionValue;
            liquidityAmount += stablecoinAmount;
        }

        address priceOracle = ICreditManagerV3(creditManager).priceOracle();
        uint256 stableCoinBalance = IERC20(stableCoinToken).balanceOf(creditAccount);

        if (unwrappedUnderlying != stableCoinToken) {
            collateralValue += stableCoinBalance;
            collateralValue = IPriceOracleV3(priceOracle).convert(collateralValue, stableCoinToken, underlying);

            liquidityAmount += stableCoinBalance;
            liquidityAmount = IPriceOracleV3(priceOracle).convert(liquidityAmount, stableCoinToken, underlying);
            liquidityAmount += IERC20(unwrappedUnderlying).balanceOf(creditAccount);
        } else {
            liquidityAmount += stableCoinBalance;
        }
        liquidityAmount += IERC20(underlying).balanceOf(creditAccount);
        liquidityAmount = liquidityAmount * liquidationDiscount / PERCENTAGE_FACTOR;

        uint256 dsTokenBalance = IERC20(dsToken).balanceOf(creditAccount);
        collateralValue += IPriceOracleV3(priceOracle).convert(dsTokenBalance, dsToken, underlying);

        return (collateralValue, liquidityAmount);
    }

    function _getLiquidationCalls(
        address creditAccount,
        address creditManager,
        address creditFacade,
        address redemptionGateway,
        address underlying,
        uint256 underlyingAmount,
        address[] memory redeemers,
        address to
    ) internal view returns (MultiCall[] memory) {
        address gatewayAdapter = ICreditManagerV3(creditManager).contractToAdapter(redemptionGateway);

        MultiCall[] memory calls = new MultiCall[](redeemers.length + 1);

        for (uint256 i = 0; i < redeemers.length; i++) {
            calls[i] = MultiCall({
                target: address(gatewayAdapter),
                callData: abi.encodeCall(ISecuritizeRedemptionGatewayAdapter.transferRedeemer, (redeemers[i], to))
            });
        }

        calls[redeemers.length] = MultiCall({
            target: creditFacade,
            callData: abi.encodeCall(ICreditFacadeV3Multicall.addCollateral, (underlying, underlyingAmount))
        });
        {
            address dsToken = ISecuritizeRedemptionGateway(redemptionGateway).dsToken();
            uint256 dsTokenBalance = IERC20(dsToken).balanceOf(creditAccount);
            if (dsTokenBalance > 0) {
                calls = _append(
                    calls,
                    MultiCall({
                        target: creditFacade,
                        callData: abi.encodeCall(
                            ICreditFacadeV3Multicall.withdrawCollateral, (dsToken, dsTokenBalance, to)
                        )
                    })
                );
            }
        }

        calls = _appendStablecoinUnderlyingCalls(
            calls, creditAccount, creditManager, creditFacade, redemptionGateway, underlying, to
        );

        return calls;
    }

    function _appendStablecoinUnderlyingCalls(
        MultiCall[] memory calls,
        address creditAccount,
        address creditManager,
        address creditFacade,
        address redemptionGateway,
        address underlying,
        address to
    ) internal view returns (MultiCall[] memory) {
        address unwrappedUnderlying = IERC4626(underlying).asset();
        uint256 unwrappedUnderlyingBalance = IERC20(unwrappedUnderlying).balanceOf(creditAccount);
        address stableCoinToken = ISecuritizeRedemptionGateway(redemptionGateway).stableCoinToken();

        if (stableCoinToken != unwrappedUnderlying) {
            uint256 stableCoinBalance = IERC20(stableCoinToken).balanceOf(creditAccount);
            if (stableCoinBalance > 0) {
                calls = _append(
                    calls,
                    MultiCall({
                        target: creditFacade,
                        callData: abi.encodeCall(
                            ICreditFacadeV3Multicall.withdrawCollateral, (stableCoinToken, stableCoinBalance, to)
                        )
                    })
                );
            }
        }
        if (unwrappedUnderlyingBalance > 0) {
            address underlyingAdapter = ICreditManagerV3(creditManager).contractToAdapter(underlying);
            calls = _append(
                calls,
                MultiCall({target: underlyingAdapter, callData: abi.encodeCall(IERC4626Adapter.depositDiff, (1))})
            );
        }
        return calls;
    }

    function _getLiquidationDiscount(address creditManager, CollateralDebtData memory cdd)
        internal
        view
        returns (uint16)
    {
        (,, uint16 liquidationDiscount,, uint16 liquidationDiscountExpired) = ICreditManagerV3(creditManager).fees();
        return cdd.totalDebtUSD > cdd.twvUSD ? liquidationDiscount : liquidationDiscountExpired;
    }

    function _applyPriceUpdates(address creditFacade, PriceUpdate[] memory priceUpdates) internal {
        if (priceUpdates.length == 0) return;
        address priceFeedStore = ICreditFacadeV3(creditFacade).priceFeedStore();
        IPriceFeedStore(priceFeedStore).updatePrices(priceUpdates);
    }

    function _transferAndWrapStablecoin(address underlying, uint256 underlyingAmount) internal {
        address stableCoinToken = IERC4626(underlying).asset();
        IERC20(stableCoinToken).safeTransferFrom(msg.sender, address(this), underlyingAmount);
        IERC20(stableCoinToken).forceApprove(underlying, underlyingAmount);
        IERC4626(underlying).deposit(underlyingAmount, address(this));
    }

    function _append(MultiCall[] memory calls, MultiCall memory call)
        internal
        pure
        returns (MultiCall[] memory newCalls)
    {
        uint256 len = calls.length;
        newCalls = new MultiCall[](len + 1);
        for (uint256 i = 0; i < len; i++) {
            newCalls[i] = calls[i];
        }
        newCalls[len] = call;
        return newCalls;
    }
}
