// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IMellowVaultAdapter, MellowUnderlyingStatus} from "../../interfaces/mellow/IMellowVaultAdapter.sol";
import {IMellowVault} from "../../integrations/mellow/IMellowVault.sol";

/// @title Mellow vault adapter
/// @notice Implements logic for interacting with the Mellow vault contract (deposits only)
contract MellowVaultAdapter is AbstractAdapter, IMellowVaultAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "AD_MELLOW_LRT_VAULT";
    uint256 public constant override version = 3_10;

    /// @dev Set of allowed underlying addresses
    EnumerableSet.AddressSet internal _allowedUnderlyings;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _mellowVault Mellow vault address
    constructor(address _creditManager, address _mellowVault) AbstractAdapter(_creditManager, _mellowVault) {
        _getMaskOrRevert(_mellowVault); // U:[MEL-1]
    }

    /// @notice Deposits specified amounts of tokens into the vault in exchange for LP tokens.
    /// @param amounts An array specifying the amounts for each underlying token.
    /// @param minLpAmount The minimum amount of LP tokens to mint.
    /// @param deadline The time before which the operation must be completed.
    /// @notice `to` is ignored as the recipient is always the credit account
    function deposit(address, uint256[] memory amounts, uint256 minLpAmount, uint256 deadline)
        external
        creditFacadeOnly // U:[MEL-2]
        returns (bool)
    {
        address creditAccount = _creditAccount();

        address[] memory underlyings = IMellowVault(targetContract).underlyingTokens();

        uint256 len = underlyings.length;

        if (amounts.length != len) revert IncorrectArrayLengthException(); // U:[MEL-3]

        for (uint256 i = 0; i < len;) {
            if (!_allowedUnderlyings.contains(underlyings[i])) {
                revert UnderlyingNotAllowedException(underlyings[i]); // U:[MEL-3]
            }

            unchecked {
                ++i;
            }
        }

        _approveAssets(underlyings, amounts, type(uint256).max);
        _execute(abi.encodeCall(IMellowVault.deposit, (creditAccount, amounts, minLpAmount, deadline))); // U:[MEL-3]
        _approveAssets(underlyings, amounts, 1);

        return true;
    }

    /// @notice Deposits a specififed amount of one underlying into the vault in exchange for LP tokens.
    /// @param asset The asset to deposit
    /// @param amount Amount of underlying to deposit.
    /// @param minLpAmount The minimum amount of LP tokens to mint.
    /// @param deadline The time before which the operation must be completed.
    function depositOneAsset(address asset, uint256 amount, uint256 minLpAmount, uint256 deadline)
        external
        creditFacadeOnly
        returns (bool)
    {
        if (!_allowedUnderlyings.contains(asset)) revert UnderlyingNotAllowedException(asset); // U:[MEL-4]

        address creditAccount = _creditAccount();

        return _depositOneAsset(creditAccount, asset, amount, minLpAmount, deadline); // U:[MEL-4]
    }

    /// @notice Deposits the entire balance of one underlying, except the specified amount, into the vault in exchange for LP tokens.
    /// @param asset The asset to deposit
    /// @param leftoverAmount Amount of underlying to leave on the Credit Account.
    /// @param rateMinRAY The minimum exchange rate between the deposited asset and LP, in 1e27 format.
    /// @param deadline The time before which the operation must be completed.
    function depositOneAssetDiff(address asset, uint256 leftoverAmount, uint256 rateMinRAY, uint256 deadline)
        external
        creditFacadeOnly
        returns (bool)
    {
        if (!_allowedUnderlyings.contains(asset)) revert UnderlyingNotAllowedException(asset); // U:[MEL-5]

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(asset).balanceOf(creditAccount);

        if (amount <= leftoverAmount) return false;

        unchecked {
            amount = amount - leftoverAmount;
        }

        return _depositOneAsset(creditAccount, asset, amount, amount * rateMinRAY / RAY, deadline); // U:[MEL-5]
    }

    /// @dev Internal implementation for `depositOneAsset` and `depositOneAssetDiff`
    function _depositOneAsset(
        address creditAccount,
        address asset,
        uint256 amount,
        uint256 minLpAmount,
        uint256 deadline
    ) internal returns (bool) {
        address[] memory underlyings = IMellowVault(targetContract).underlyingTokens();
        uint256 len = underlyings.length;

        uint256[] memory amounts = new uint256[](len);

        for (uint256 i = 0; i < len;) {
            if (underlyings[i] == asset) {
                amounts[i] = amount;
                break;
            }

            if (i == len - 1) revert UnderlyingNotFoundException(asset); // U:[MEL-4,5]

            unchecked {
                ++i;
            }
        }

        _approveToken(asset, type(uint256).max);
        _execute(abi.encodeCall(IMellowVault.deposit, (creditAccount, amounts, minLpAmount, deadline))); // U:[MEL-4,5]
        _approveToken(asset, 1);
        return true;
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

    // ---- //
    // DATA //
    // ---- //

    /// @notice Returns the list of allowed underlyings
    function allowedUnderlyings() public view returns (address[] memory) {
        return _allowedUnderlyings.values();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, allowedUnderlyings());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Changes the allowed status of several underlyings
    function setUnderlyingStatusBatch(MellowUnderlyingStatus[] calldata underlyings)
        external
        override
        configuratorOnly // U:[MEL-6]
    {
        uint256 len = underlyings.length;
        for (uint256 i; i < len; ++i) {
            if (underlyings[i].allowed) {
                _getMaskOrRevert(underlyings[i].underlying);
                _allowedUnderlyings.add(underlyings[i].underlying);
            } else {
                _allowedUnderlyings.remove(underlyings[i].underlying);
            }
            emit SetUnderlyingStatus(underlyings[i].underlying, underlyings[i].allowed); // U:[MEL-6]
        }
    }
}
