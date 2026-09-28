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

import {IMidasGateway} from "./interfaces/IMidasGateway.sol";
import {IMidasRedemptionVault, RedemptionStatus} from "./interfaces/external/IMidasRedemptionVault.sol";
import {MidasRedeemer} from "./MidasRedeemer.sol";

bytes32 constant MIDAS_PHANTOM_TOKEN_TYPE = "PHANTOM_TOKEN::MIDAS_REDEMPTION";

/// @title Midas aliased loss policy V3
/// @notice Extends `AliasedLossPolicyV3` with a gate that forbids loss liquidations while any pending Midas
///         redemption on the account has been rejected by Midas
contract MidasAliasedLossPolicyV3 is AliasedLossPolicyV3 {
    using BitMask for uint256;

    /// @notice Contract version
    function version() external view override returns (uint256) {
        return 3_11;
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
    /// @dev When `checksEnabled`, blocks if any pending Midas redemption was rejected, then defers to the parent
    function isLiquidatableWithLoss(address creditAccount, address caller, Params calldata params)
        public
        override
        returns (bool)
    {
        if (checksEnabled && _hasRejectedMidasRedemption(creditAccount)) return false;
        return super.isLiquidatableWithLoss(creditAccount, caller, params);
    }

    /// @dev Whether any enabled Midas phantom token on `creditAccount` has a pending redeemer with REJECTED status
    function _hasRejectedMidasRedemption(address creditAccount) internal view returns (bool) {
        address creditManager = ICreditAccountV3(creditAccount).creditManager();
        uint256 remainingTokensMask =
            ICreditManagerV3(creditManager).enabledTokensMaskOf(creditAccount).disable(UNDERLYING_TOKEN_MASK);

        while (remainingTokensMask != 0) {
            uint256 tokenMask = remainingTokensMask.lsbMask();
            remainingTokensMask ^= tokenMask;

            address token = ICreditManagerV3(creditManager).getTokenByMask(tokenMask);
            if (!_isMidasPhantomToken(token)) continue;

            (address gateway,) = IPhantomToken(token).getPhantomTokenInfo();
            address vault = IMidasGateway(gateway).midasRedemptionVault();
            address[] memory redeemers = IMidasGateway(gateway).pendingRedeemers(creditAccount);

            for (uint256 i; i < redeemers.length; ++i) {
                uint256 requestId = MidasRedeemer(redeemers[i]).requestId();
                (,, RedemptionStatus status,,,) = IMidasRedemptionVault(vault).redeemRequests(requestId);
                if (status == RedemptionStatus.REJECTED) return true;
            }
        }

        return false;
    }

    /// @dev Whether `token` reports `PHANTOM_TOKEN::MIDAS_REDEMPTION` via a gas-capped optional staticcall
    function _isMidasPhantomToken(address token) internal view returns (bool) {
        (bool success, bytes memory returnData) = OptionalCall.staticCallOptionalSafe({
            target: token, data: abi.encodeCall(IVersion.contractType, ()), gasAllowance: 30_000
        });
        if (!success) return false;
        return abi.decode(returnData, (bytes32)) == MIDAS_PHANTOM_TOKEN_TYPE;
    }
}
