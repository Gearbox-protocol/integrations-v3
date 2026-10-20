// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

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
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

/// @title Liquidation checks trait
/// @notice Re-applies CreditFacade pause and loss-policy gates against the real liquidator when a helper contract is
///         the Credit Facade caller
abstract contract LiquidationChecksTrait {
    error CallerNotEmergencyLiquidatorException();

    /// @dev Cuts out price updates from the MultiCall to avoid re-applying them during the multicall
    function _cutOnDemandPriceUpdates(address creditFacade, MultiCall[] calldata calls)
        internal
        pure
        returns (MultiCall[] memory, PriceUpdate[] memory priceUpdates)
    {
        if (
            calls.length != 0 && calls[0].target == creditFacade
                && bytes4(calls[0].callData) == ICreditFacadeV3Multicall.onDemandPriceUpdates.selector
        ) {
            priceUpdates = abi.decode(calls[0].callData[4:], (PriceUpdate[]));
            uint256 len = calls.length - 1;
            MultiCall[] memory remainingCalls = new MultiCall[](len);
            for (uint256 i; i < len; ++i) {
                remainingCalls[i] = calls[i + 1];
            }
            return (remainingCalls, priceUpdates);
        } else {
            return (calls, new PriceUpdate[](0));
        }
    }

    /// @dev Applies `priceUpdates` via the facade's price feed store; no-op when empty
    function _applyPriceUpdates(address creditFacade, PriceUpdate[] memory priceUpdates) internal {
        if (priceUpdates.length == 0) return;
        address priceFeedStore = ICreditFacadeV3(creditFacade).priceFeedStore();
        IPriceFeedStore(priceFeedStore).updatePrices(priceUpdates);
    }

    /// @dev Reverts unless `caller` may liquidate through this helper given the facade's pause state and loss policy
    /// @dev Mirrors `whenNotPausedOrEmergency` and the bad-debt `isLiquidatableWithLoss` branch of
    ///      `CreditFacadeV3.liquidateCreditAccount`; does not re-check general liquidatability
    function _revertIfNotAllowedToLiquidate(
        address creditFacade,
        address creditManager,
        address creditAccount,
        address caller,
        bytes memory lossPolicyData
    ) internal {
        if (Pausable(creditFacade).paused()) {
            if (!IACL(ICreditFacadeV3(creditFacade).acl()).hasRole("EMERGENCY_LIQUIDATOR", caller)) {
                revert CallerNotEmergencyLiquidatorException();
            }
        }

        CollateralDebtData memory cdd =
            ICreditManagerV3(creditManager).calcDebtAndCollateral(creditAccount, CollateralCalcTask.DEBT_COLLATERAL);
        bool isUnhealthy = cdd.twvUSD < cdd.totalDebtUSD;

        if (isUnhealthy && _hasBadDebt(creditManager, cdd)) {
            ILossPolicy.Params memory params =
                ILossPolicy.Params({totalDebtUSD: cdd.totalDebtUSD, twvUSD: cdd.twvUSD, extraData: lossPolicyData});
            address lossPolicy = ICreditFacadeV3(creditFacade).lossPolicy();
            if (!ILossPolicy(lossPolicy).isLiquidatableWithLoss(creditAccount, caller, params)) {
                revert CreditAccountNotLiquidatableWithLossException();
            }
        }
    }

    /// @dev Whether account's total value (minus liquidator's premium) is below its outstanding debt
    /// @dev Same formula as `CreditFacadeV3._hasBadDebt`
    function _hasBadDebt(address creditManager, CollateralDebtData memory cdd) internal view returns (bool) {
        (,, uint16 liquidationDiscount,,) = ICreditManagerV3(creditManager).fees();
        return cdd.totalValue * liquidationDiscount < (cdd.debt + cdd.accruedInterest) * PERCENTAGE_FACTOR;
    }
}
