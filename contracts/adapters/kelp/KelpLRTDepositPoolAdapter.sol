// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IKelpLRTDepositPoolAdapter} from "../../interfaces/kelp/IKelpLRTDepositPoolAdapter.sol";
import {IKelpLRTDepositPoolGateway} from "../../interfaces/kelp/IKelpLRTDepositPoolGateway.sol";

/// @title Kelp LRTDepositPool adapter
/// @notice Implements logic for interacting with the Kelp LRTDepositPool contract
contract KelpLRTDepositPoolAdapter is AbstractAdapter, IKelpLRTDepositPoolAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::KELP_DEPOSIT_POOL";
    uint256 public constant override version = 3_10;

    /// @dev Set of allowed underlying addresses
    EnumerableSet.AddressSet internal _allowedAssets;

    /// @notice Referral ID for the adapter
    string public override referralId;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _depositPoolGateway Deposit pool gateway address
    constructor(address _creditManager, address _depositPoolGateway, string memory _referralId)
        AbstractAdapter(_creditManager, _depositPoolGateway)
    {
        address rsETH = IKelpLRTDepositPoolGateway(_depositPoolGateway).rsETH();
        referralId = _referralId;
        _getMaskOrRevert(rsETH);
    }

    /// @notice Deposits an asset into rsETH
    /// @param asset Asset to deposit
    /// @param amount Amount of asset to deposit
    /// @param minRSETHAmountExpected Minimum amount of rsETH to receive
    /// @dev `referralId` is ignored as it is hardcoded
    function depositAsset(address asset, uint256 amount, uint256 minRSETHAmountExpected, string calldata)
        external
        creditFacadeOnly
        returns (bool)
    {
        if (!_allowedAssets.contains(asset)) revert AssetNotAllowedException(asset);

        _depositAsset(asset, amount, minRSETHAmountExpected);
        return true;
    }

    /// @notice Deposits the entire balance of the asset into rsETH, except the specified amount
    /// @param asset Asset to deposit
    /// @param leftoverAmount Amount of asset to leave on the credit account
    /// @param minRateRAY Minimum rate of rsETH to receive
    function depositAssetDiff(address asset, uint256 leftoverAmount, uint256 minRateRAY)
        external
        creditFacadeOnly
        returns (bool)
    {
        if (!_allowedAssets.contains(asset)) revert AssetNotAllowedException(asset);

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(asset).balanceOf(creditAccount);
        if (amount < leftoverAmount) return false;

        unchecked {
            amount -= leftoverAmount;
        }

        _depositAsset(asset, amount, amount * minRateRAY / RAY);
        return true;
    }

    /// @notice Internal implementation of the `depositAsset` function
    function _depositAsset(address asset, uint256 amount, uint256 minRSETHAmountExpected) internal {
        _executeSwapSafeApprove(
            asset,
            abi.encodeCall(IKelpLRTDepositPoolGateway.depositAsset, (asset, amount, minRSETHAmountExpected, referralId))
        );
    }

    // ---- //
    // DATA //
    // ---- //

    /// @notice Returns the list of allowed assets
    function allowedAssets() public view returns (address[] memory) {
        return _allowedAssets.values();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, allowedAssets());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Changes the allowed status of several assets
    function setAssetStatusBatch(address[] calldata assets, bool[] calldata allowed)
        external
        override
        configuratorOnly // U:[MEL-6]
    {
        uint256 len = assets.length;
        if (len != allowed.length) revert IncorrectArrayLengthException();
        for (uint256 i; i < len; ++i) {
            if (allowed[i]) {
                _getMaskOrRevert(assets[i]);
                _allowedAssets.add(assets[i]);
            } else {
                _allowedAssets.remove(assets[i]);
            }
            emit SetAssetStatus(assets[i], allowed[i]);
        }
    }
}
