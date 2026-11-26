// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {AliasedLossPolicyV3} from "@gearbox-protocol/core-v3/contracts/core/AliasedLossPolicyV3.sol";
import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {BitMask} from "@gearbox-protocol/core-v3/contracts/libraries/BitMask.sol";
import {UNDERLYING_TOKEN_MASK} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {OptionalCall} from "@gearbox-protocol/core-v3/contracts/libraries/OptionalCall.sol";

import {IMidasRedemptionGateway} from "./interfaces/IMidasRedemptionGateway.sol";
import {IMidasDepositGateway} from "./interfaces/IMidasDepositGateway.sol";
import {IMidasRedemptionVault, RedemptionStatus} from "./interfaces/external/IMidasRedemptionVault.sol";
import {IMidasDepositVault, DepositStatus} from "./interfaces/external/IMidasDepositVault.sol";
import {MidasRedeemer} from "./MidasRedeemer.sol";
import {MidasDepositor} from "./MidasDepositor.sol";

bytes32 constant MIDAS_REDEMPTION_PHANTOM_TOKEN_TYPE = "PHANTOM_TOKEN::MIDAS_REDEMPTION";
bytes32 constant MIDAS_DEPOSIT_PHANTOM_TOKEN_TYPE = "PHANTOM_TOKEN::MIDAS_DEPOSIT";

/// @title Midas aliased loss policy V3
/// @notice Extends `AliasedLossPolicyV3` with a gate that forbids loss liquidations while any pending Midas
///         redemption or deposit on the account has been rejected by Midas
contract MidasAliasedLossPolicyV3 is AliasedLossPolicyV3 {
    using BitMask for uint256;

    /// @notice Contract version
    function version() external view override returns (uint256) {
        return 3_12;
    }

    /// @notice Contract type
    function contractType() external view override returns (bytes32) {
        return "LOSS_POLICY::MIDAS_ALIASED";
    }

    /// @notice Constructor
    /// @param pool_ Pool address
    /// @param addressProvider_ Address provider contract address
    constructor(address pool_, address addressProvider_) AliasedLossPolicyV3(pool_, addressProvider_) {}

    /// @notice Returns whether `creditAccount` can be liquidated with loss by `caller`
    /// @dev When `checksEnabled`, blocks if any pending Midas request was rejected, then defers to the parent
    function isLiquidatableWithLoss(address creditAccount, address caller, Params calldata params)
        public
        override
        returns (bool)
    {
        if (checksEnabled && _hasRejectedMidasRequest(creditAccount)) return false;
        return super.isLiquidatableWithLoss(creditAccount, caller, params);
    }

    /// @dev Whether any enabled Midas phantom token on `creditAccount` has a pending request with REJECTED status
    function _hasRejectedMidasRequest(address creditAccount) internal view returns (bool) {
        address creditManager = ICreditAccountV3(creditAccount).creditManager();
        uint256 remainingTokensMask =
            ICreditManagerV3(creditManager).enabledTokensMaskOf(creditAccount).disable(UNDERLYING_TOKEN_MASK);

        while (remainingTokensMask != 0) {
            uint256 tokenMask = remainingTokensMask.lsbMask();
            remainingTokensMask ^= tokenMask;

            address token = ICreditManagerV3(creditManager).getTokenByMask(tokenMask);
            bytes32 phantomType = _midasPhantomTokenType(token);
            if (phantomType == bytes32(0)) continue;

            (address gateway,) = IPhantomToken(token).getPhantomTokenInfo();

            if (phantomType == MIDAS_REDEMPTION_PHANTOM_TOKEN_TYPE) {
                if (_hasRejectedRedemption(gateway, creditAccount)) return true;
            } else if (phantomType == MIDAS_DEPOSIT_PHANTOM_TOKEN_TYPE) {
                if (_hasRejectedDeposit(gateway, creditAccount)) return true;
            }
        }

        return false;
    }

    function _hasRejectedRedemption(address gateway, address creditAccount) internal view returns (bool) {
        address vault = IMidasRedemptionGateway(gateway).midasRedemptionVault();
        address[] memory redeemers = IMidasRedemptionGateway(gateway).pendingRedeemers(creditAccount);

        for (uint256 i; i < redeemers.length; ++i) {
            uint256 requestId = MidasRedeemer(redeemers[i]).requestId();
            (,, RedemptionStatus status,,,,,,,) = IMidasRedemptionVault(vault).redeemRequests(requestId);
            if (status == RedemptionStatus.REJECTED) return true;
        }
        return false;
    }

    function _hasRejectedDeposit(address gateway, address creditAccount) internal view returns (bool) {
        address vault = IMidasDepositGateway(gateway).midasDepositVault();
        address[] memory depositors = IMidasDepositGateway(gateway).pendingDepositors(creditAccount);

        for (uint256 i; i < depositors.length; ++i) {
            uint256 requestId = MidasDepositor(depositors[i]).requestId();
            (,, DepositStatus status,,,,,,) = IMidasDepositVault(vault).mintRequests(requestId);
            if (status == DepositStatus.REJECTED) return true;
        }
        return false;
    }

    /// @dev Returns the Midas phantom token type, or zero if `token` is not one
    function _midasPhantomTokenType(address token) internal view returns (bytes32) {
        (bool success, bytes memory returnData) = OptionalCall.staticCallOptionalSafe({
            target: token, data: abi.encodeCall(IVersion.contractType, ()), gasAllowance: 30_000
        });
        if (!success) return bytes32(0);

        bytes32 phantomType = abi.decode(returnData, (bytes32));
        if (phantomType == MIDAS_REDEMPTION_PHANTOM_TOKEN_TYPE || phantomType == MIDAS_DEPOSIT_PHANTOM_TOKEN_TYPE) {
            return phantomType;
        }
        return bytes32(0);
    }
}
