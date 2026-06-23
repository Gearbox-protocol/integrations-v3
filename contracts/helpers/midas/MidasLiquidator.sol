// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditFacadeV3, MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {IPriceFeedStore, PriceUpdate} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeedStore.sol";

import {IMidasGateway} from "../../interfaces/midas/IMidasGateway.sol";
import {IMidasLiquidator} from "../../interfaces/midas/IMidasLiquidator.sol";

/// @title Midas liquidator
/// @notice Acts as the transfer master for Midas gateways, enabling redeemer transfers for the duration of a
///         liquidation. Unlike RWA integrations that price pending positions differently for collateral valuation
///         and liquidation, Midas values pending redemptions identically in both cases, so this contract performs
///         no collateral/liquidity math and simply forwards the liquidator-supplied calls while the transfer flag
///         is raised.
contract MidasLiquidator is IMidasLiquidator {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "RWA_LIQUIDATOR::MIDAS";

    uint256 public constant override version = 3_11;

    bool public override isTransferAllowed;

    /// @notice Liquidates a credit account that holds pending Midas redemptions
    /// @param creditAccount Credit account to liquidate
    /// @param gateway Midas gateway whose redeemers are transferred during the liquidation
    /// @param calls Liquidator-supplied multicall forwarded to the credit facade
    /// @param lossPolicyData Loss policy data forwarded to the credit facade
    /// @dev Any collateral the liquidator adds via `addCollateral` calls is pulled from the caller and approved to the
    ///      credit manager automatically, based on the tokens and amounts encoded in those calls
    function liquidateWithRedeemerTransfers(
        address creditAccount,
        address gateway,
        MultiCall[] calldata calls,
        bytes memory lossPolicyData
    ) external override {
        if (IMidasGateway(gateway).transferMaster() != address(this)) {
            revert NotValidGatewayException();
        }

        address creditManager = ICreditAccountV3(creditAccount).creditManager();

        if (ICreditManagerV3(creditManager).contractToAdapter(gateway) == address(0)) {
            revert NotValidGatewayException();
        }

        address creditFacade = ICreditManagerV3(creditManager).creditFacade();

        _forwardCollateral(creditManager, creditFacade, calls, false);

        isTransferAllowed = true;
        ICreditFacadeV3(creditFacade).liquidateCreditAccount(creditAccount, msg.sender, calls, lossPolicyData);
        isTransferAllowed = false;

        _forwardCollateral(creditManager, creditFacade, calls, true);
    }

    function _forwardCollateral(
        address creditManager,
        address creditFacade,
        MultiCall[] calldata calls,
        bool toLiquidator
    ) internal {
        for (uint256 i; i < calls.length; ++i) {
            if (calls[i].target != creditFacade || calls[i].callData.length < 4) continue;
            if (bytes4(calls[i].callData) != ICreditFacadeV3Multicall.addCollateral.selector) continue;
            (address token, uint256 amount) = abi.decode(calls[i].callData[4:], (address, uint256));
            if (toLiquidator) {
                IERC20(token).forceApprove(creditManager, 0);
                uint256 balance = IERC20(token).balanceOf(address(this));
                if (balance != 0) IERC20(token).safeTransfer(msg.sender, balance);
            } else {
                IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
                IERC20(token).forceApprove(creditManager, IERC20(token).balanceOf(address(this)));
            }
        }
    }
}
