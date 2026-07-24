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

import {IMidasGateway} from "./interfaces/IMidasGateway.sol";
import {IMidasLiquidator} from "./interfaces/IMidasLiquidator.sol";

/// @title Midas liquidator
/// @notice Acts as the transfer master for Midas gateways, enabling redeemer transfers for the duration of a
///         liquidation. Unlike RWA integrations that price pending positions differently for collateral valuation
///         and liquidation, Midas values pending redemptions identically in both cases, so this contract performs
///         no collateral/liquidity math and simply forwards the liquidator-supplied calls while transfers are
///         unlocked for the liquidated account.
contract MidasLiquidator is IMidasLiquidator {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "RWA_LIQUIDATOR::MIDAS";

    uint256 public constant override version = 3_11;

    /// @notice The address of the account that is currently allowed to transfer redeemers.
    /// @dev For safety, redeemers are only allowed to be transferred when strictly required,
    ///      i.e. during liquidations, and only by a specific account.
    address public override transferableRedeemerOwner;

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

        _forwardCollateral(creditManager, creditFacade, calls);

        transferableRedeemerOwner = creditAccount;
        ICreditFacadeV3(creditFacade).liquidateCreditAccount(creditAccount, msg.sender, calls, lossPolicyData);
        transferableRedeemerOwner = address(0);
    }

    function isTransferAllowed(address redeemerOwner) external view override returns (bool) {
        return redeemerOwner == transferableRedeemerOwner;
    }

    /// @dev Forwards collateral from the liquidator to the credit manager, via this contract
    /// @dev Since CreditManagerV3 only transfers tokens from the `multicall()` caller, we need to transfer
    ///      tokens from the liquidator to this contract.
    function _forwardCollateral(address creditManager, address creditFacade, MultiCall[] calldata calls) internal {
        for (uint256 i; i < calls.length; i++) {
            if (
                calls[i].target == creditFacade
                    && (bytes4(calls[i].callData) == ICreditFacadeV3Multicall.addCollateral.selector)
            ) {
                (address token, uint256 amount) = abi.decode(calls[i].callData[4:], (address, uint256));
                IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
                IERC20(token).forceApprove(creditManager, amount);
            }
        }
    }
}
