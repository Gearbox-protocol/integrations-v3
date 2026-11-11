// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {TokenNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AbstractAdapter} from "../common/AbstractAdapter.sol";
import {IAaveV3Pool} from "./interfaces/external/IAaveV3Pool.sol";
import {AaveV3AssetStatus, IAaveV3PoolAdapter} from "./interfaces/IAaveV3PoolAdapter.sol";

/// @title Aave V3 Pool adapter
/// @notice Allows Credit Accounts to supply and withdraw on an Aave V3 Pool
/// @dev `onBehalfOf` / `to` are always forced to the credit account so RWA aToken minting (`caller == onBehalfOf`) works
contract AaveV3PoolAdapter is AbstractAdapter, IAaveV3PoolAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::AAVE_V3_POOL";
    uint256 public constant override version = 3_11;

    /// @inheritdoc IAaveV3PoolAdapter
    address public immutable override pool;

    /// @inheritdoc IAaveV3PoolAdapter
    uint16 public immutable override referralCode;

    /// @dev Allowed underlying assets
    EnumerableSet.AddressSet internal _allowedAssets;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _pool Aave V3 Pool address
    /// @param _referralCode Integrator referral code passed to Aave `supply`
    constructor(address _creditManager, address _pool, uint16 _referralCode) AbstractAdapter(_creditManager, _pool) {
        pool = _pool;
        referralCode = _referralCode;
    }

    /// @inheritdoc IAaveV3PoolAdapter
    function supply(address asset, uint256 amount, address, uint16) external override creditFacadeOnly returns (bool) {
        return _supply(_creditAccount(), asset, amount);
    }

    /// @inheritdoc IAaveV3PoolAdapter
    function supplyDiff(address asset, uint256 leftoverAmount) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(asset).balanceOf(creditAccount);
        if (balance <= leftoverAmount) return false;

        unchecked {
            return _supply(creditAccount, asset, balance - leftoverAmount);
        }
    }

    /// @dev Supplies `amount` of `asset` from the credit account
    function _supply(address creditAccount, address asset, uint256 amount) internal returns (bool) {
        if (!_allowedAssets.contains(asset)) revert TokenNotAllowedException();
        _executeSwapSafeApprove(asset, abi.encodeCall(IAaveV3Pool.supply, (asset, amount, creditAccount, referralCode)));
        return false;
    }

    /// @inheritdoc IAaveV3PoolAdapter
    function withdraw(address asset, uint256 amount, address) external override creditFacadeOnly returns (bool) {
        return _withdraw(_creditAccount(), asset, amount);
    }

    /// @inheritdoc IAaveV3PoolAdapter
    function withdrawDiff(address asset, uint256 leftoverAmount) external override creditFacadeOnly returns (bool) {
        if (!_allowedAssets.contains(asset)) revert TokenNotAllowedException();

        address creditAccount = _creditAccount();
        address aToken = IAaveV3Pool(pool).getReserveAToken(asset);
        uint256 balance = IERC20(aToken).balanceOf(creditAccount);
        if (balance <= leftoverAmount) return false;

        unchecked {
            // Aave `withdraw` takes underlying amount; with 1:1 aTokens this matches aToken units
            return _withdraw(creditAccount, asset, balance - leftoverAmount);
        }
    }

    /// @dev Withdraws `amount` of underlying `asset` to the credit account
    function _withdraw(address creditAccount, address asset, uint256 amount) internal returns (bool) {
        if (!_allowedAssets.contains(asset)) revert TokenNotAllowedException();
        _execute(abi.encodeCall(IAaveV3Pool.withdraw, (asset, amount, creditAccount)));
        return false;
    }

    // ---- //
    // DATA //
    // ---- //

    /// @inheritdoc IAaveV3PoolAdapter
    function isAssetAllowed(address asset) external view override returns (bool) {
        return _allowedAssets.contains(asset);
    }

    /// @inheritdoc IAaveV3PoolAdapter
    function allowedAssets() public view override returns (address[] memory) {
        return _allowedAssets.values();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, pool, referralCode, allowedAssets());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @inheritdoc IAaveV3PoolAdapter
    function setAssetStatusBatch(AaveV3AssetStatus[] calldata assets) external override configuratorOnly {
        uint256 len = assets.length;
        for (uint256 i; i < len; ++i) {
            address asset = assets[i].asset;
            if (assets[i].allowed) {
                address aToken = IAaveV3Pool(pool).getReserveAToken(asset);
                _getMaskOrRevert(asset);
                _getMaskOrRevert(aToken);
                _allowedAssets.add(asset);
            } else {
                _allowedAssets.remove(asset);
            }
            emit SetAssetStatus(asset, assets[i].allowed);
        }
    }
}
