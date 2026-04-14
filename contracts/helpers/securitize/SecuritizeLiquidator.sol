// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ISecuritizeLiquidator} from "../../interfaces/securitize/ISecuritizeLiquidator.sol";

import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {
    ICreditManagerV3,
    CollateralDebtData,
    CollateralCalcTask
} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditFacadeV3, MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {IPriceFeedStore, PriceUpdate} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeedStore.sol";
import {CreditLogic} from "@gearbox-protocol/core-v3/contracts/libraries/CreditLogic.sol";

import {ISecuritizeRedemptionGateway} from "../../interfaces/securitize/ISecuritizeRedemptionGateway.sol";
import {ISecuritizeRedemptionGatewayAdapter} from "../../interfaces/securitize/ISecuritizeRedemptionGatewayAdapter.sol";
import {ISecuritizeWhitelister} from "../../integrations/securitize/ISecuritizeWhitelister.sol";
import {ISecuritizeGatewayTransferMaster} from "../../interfaces/securitize/ISecuritizeGatewayTransferMaster.sol";
import {SecuritizeRedeemer} from "./SecuritizeRedeemer.sol";

import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

contract SecuritizeLiquidator is ISecuritizeLiquidator {
    using SafeERC20 for IERC20;
    using CreditLogic for CollateralDebtData;

    bytes32 public constant override contractType = "HELPER::SECURITIZE_LIQUIDATOR";
    uint256 public constant override version = 3_10;

    address public immutable dsToken;

    bool public isTransferAllowed;

    modifier enableRedemptionTransfer() {
        isTransferAllowed = true;
        _;
        isTransferAllowed = false;
    }

    function liquidatePendingRedemption(
        address creditAccount,
        address redemptionGateway,
        PriceUpdate[] memory priceUpdates
    ) external enableRedemptionTransfer {
        if (ISecuritizeRedemptionGateway(redemptionGateway).transferMaster() != address(this)) {
            revert NotValidGatewayException();
        }

        address creditManager = ICreditAccountV3(creditAccount).creditManager();
        address creditFacade = ICreditManagerV3(creditManager).creditFacade();

        _applyPriceUpdates(creditFacade, priceUpdates);

        address underlying = ICreditManagerV3(creditManager).underlying();

        CollateralDebtData memory cdd =
            ICreditManagerV3(creditManager).calcDebtAndCollateral(creditAccount, CollateralCalcTask.DEBT_COLLATERAL);

        if (cdd.debt == 0 || (cdd.twvUSD >= cdd.totalDebtUSD)) {
            revert CreditAccountNotLiquidatableException();
        }

        (,, uint16 liquidationDiscount,,) = ICreditManagerV3(creditManager).fees();

        address[] memory redeemers =
            ISecuritizeRedemptionGateway(redemptionGateway).getUnclaimedRedeemers(creditAccount);

        (uint256 redemptionValue, uint256 liquidityAmount) =
            _calcRedemptionAndLiquidityValues(creditAccount, underlying, redemptionGateway, redeemers);

        uint256 underlyingAmount = redemptionValue * liquidationDiscount / PERCENTAGE_FACTOR;

        if (liquidityAmount >= cdd.calcTotalDebt()) {
            revert AccountHasSufficientLiquidityException();
        }

        MultiCall[] memory calls = _getLiquidationCalls(
            creditManager, creditFacade, redemptionGateway, underlying, underlyingAmount, redeemers, msg.sender
        );
        
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), underlyingAmount);
        IERC20(underlying).approve(creditManager, underlyingAmount);

        ICreditFacadeV3(creditFacade).liquidateCreditAccount(creditAccount, msg.sender, calls, "");
    }

    function _calcRedemptionAndLiquidityValues(
        address creditAccount,
        address underlying,
        address redemptionGateway,
        address[] memory redeemers
    ) internal view returns (uint256 redemptionValue, uint256 liquidityAmount) {
        address stableCoinToken = ISecuritizeRedemptionGateway(redemptionGateway).stableCoinToken();

        for (uint256 i = 0; i < redeemers.length; i++) {
            redemptionValue += SecuritizeRedeemer(redeemers[i]).getCurrentRedemptionValue();
            liquidityAmount += IERC20(stableCoinToken).balanceOf(redeemers[i]);
        }

        liquidityAmount += IERC20(underlying).balanceOf(creditAccount);

        return (redemptionValue, liquidityAmount);
    }

    function _getLiquidationCalls(
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
        return calls;
    }

    function _applyPriceUpdates(address creditFacade, PriceUpdate[] memory priceUpdates) internal {
        if (priceUpdates.length == 0) return;
        address priceFeedStore = ICreditFacadeV3(creditFacade).priceFeedStore();
        IPriceFeedStore(priceFeedStore).updatePrices(priceUpdates);
    }
}
