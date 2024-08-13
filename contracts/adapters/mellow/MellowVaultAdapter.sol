// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IMellowVaultAdapter, MellowUnderlyingStatus} from "../../interfaces/mellow/IMellowVaultAdapter.sol";
import {IMellowVault} from "../../integrations/mellow/IMellowVault.sol";

/// @title Mellow vault adapter
/// @notice Implements logic for interacting with the Mellow vault contract (deposits only)
contract MellowVaultAdapter is AbstractAdapter, IMellowVaultAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.MELLOW_LRT_VAULT;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice Mapping from underlying address to its status
    mapping(address => bool) public isUnderlyingAllowed;

    /// @notice Collateral token mask of the vault token
    uint256 public immutable vaultTokenMask;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _mellowVault Mellow vault address
    constructor(address _creditManager, address _mellowVault) AbstractAdapter(_creditManager, _mellowVault) {
        vaultTokenMask = _getMaskOrRevert(_mellowVault);
    }

    /// @notice Deposits specified amounts of tokens into the vault in exchange for LP tokens.
    /// @param amounts An array specifying the amounts for each underlying token.
    /// @param minLpAmount The minimum amount of LP tokens to mint.
    /// @param deadline The time before which the operation must be completed.
    /// @notice `to` is ignored as the recipient is always the credit account
    function deposit(address, uint256[] memory amounts, uint256 minLpAmount, uint256 deadline)
        external
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        address[] memory underlyings = IMellowVault(targetContract).underlyingTokens();

        uint256 len = underlyings.length;

        for (uint256 i = 0; i < len;) {
            if (amounts[i] > 0 && !isUnderlyingAllowed[underlyings[i]]) {
                revert UnderlyingNotAllowedException(underlyings[i]);
            }

            unchecked {
                ++i;
            }
        }

        _approveAssets(underlyings, amounts, type(uint256).max);
        _execute(abi.encodeCall(IMellowVault.deposit, (creditAccount, amounts, minLpAmount, deadline)));
        _approveAssets(underlyings, amounts, 1);

        (tokensToEnable, tokensToDisable) = (vaultTokenMask, 0);
    }

    /// @notice Deposits a specififed amount of one underlying into the vault in exchange for LP tokens.
    /// @param asset The asset to deposit
    /// @param amount Amount of underlying to deposit.
    /// @param minLpAmount The minimum amount of LP tokens to mint.
    /// @param deadline The time before which the operation must be completed.
    function depositOneAsset(address asset, uint256 amount, uint256 minLpAmount, uint256 deadline)
        external
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        if (!isUnderlyingAllowed[asset]) revert UnderlyingNotAllowedException(asset);

        address creditAccount = _creditAccount();

        (tokensToEnable, tokensToDisable) = _depositOneAsset(creditAccount, asset, amount, minLpAmount, deadline, false);
    }

    /// @notice Deposits the entire balance of one underlying, except the specified amount, into the vault in exchange for LP tokens.
    /// @param asset The asset to deposit
    /// @param leftoverAmount Amount of underlying to leave on the Credit Account.
    /// @param rateMinRAY The minimum exchange rate between the deposited asset and LP, in 1e27 format.
    /// @param deadline The time before which the operation must be completed.
    function depositOneAssetDiff(address asset, uint256 leftoverAmount, uint256 rateMinRAY, uint256 deadline)
        external
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        if (!isUnderlyingAllowed[asset]) revert UnderlyingNotAllowedException(asset);

        address creditAccount = _creditAccount();

        uint256 balance = IERC20(asset).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                uint256 amount = balance - leftoverAmount;
                (tokensToEnable, tokensToDisable) = _depositOneAsset(
                    creditAccount, asset, amount, amount * rateMinRAY / RAY, deadline, leftoverAmount <= 1
                );
            }
        }
    }

    /// @dev Internal implementation for `depositOneAsset` and `depositOneAssetDiff`
    function _depositOneAsset(
        address creditAccount,
        address asset,
        uint256 amount,
        uint256 minLpAmount,
        uint256 deadline,
        bool disableTokenIn
    ) internal returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        address[] memory underlyings = IMellowVault(targetContract).underlyingTokens();
        uint256 len = underlyings.length;

        uint256[] memory amounts = new uint256[](len);

        for (uint256 i = 0; i < len;) {
            if (underlyings[i] == asset) {
                amounts[i] = amount;
                break;
            }

            unchecked {
                ++i;
            }
        }

        _approveToken(asset, type(uint256).max);
        _execute(abi.encodeCall(IMellowVault.deposit, (creditAccount, amounts, minLpAmount, deadline)));
        _approveToken(asset, 1);
        (tokensToEnable, tokensToDisable) = (vaultTokenMask, disableTokenIn ? _getMaskOrRevert(asset) : 0);
    }

    /// @dev Internal function that changes approval for a batch of assets
    function _approveAssets(address[] memory assets, uint256[] memory filter, uint256 amount) internal {
        uint256 len = assets.length;

        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                if (filter[i] > 1) _approveToken(assets[i], amount);
            }
        }
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Changes the allowed status of several underlyings
    function setUnderlyingStatusBatch(MellowUnderlyingStatus[] calldata underlyings)
        external
        override
        configuratorOnly
    {
        uint256 len = underlyings.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                isUnderlyingAllowed[underlyings[i].underlying] = underlyings[i].allowed;
                emit SetUnderlyingStatus(underlyings[i].underlying, underlyings[i].allowed);
            }
        }
    }
}
