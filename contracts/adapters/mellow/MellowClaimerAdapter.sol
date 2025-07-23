// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {IMellowClaimer} from "../../integrations/mellow/IMellowClaimer.sol";
import {
    IMellowMultiVault,
    IEigenLayerWithdrawalQueue,
    Subvault,
    MellowProtocol
} from "../../integrations/mellow/IMellowMultiVault.sol";
import {IMellowClaimerAdapter, MellowMultiVaultStatus} from "../../interfaces/mellow/IMellowClaimerAdapter.sol";
import {MellowWithdrawalPhantomToken} from "../../helpers/mellow/MellowWithdrawalPhantomToken.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Mellow Claimer adapter
/// @notice Implements logic allowing CAs to interact with a Mellow Claimer, which allows them to claim mature withdrawals.
contract MellowClaimerAdapter is AbstractAdapter, IMellowClaimerAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::MELLOW_CLAIMER";
    uint256 public constant override version = 3_10;

    /// @notice Maps a staked phantom token to the multiVault it represents
    mapping(address stakedPhantomToken => address multiVault) public phantomTokenToMultiVault;

    /// @notice Set of allowed multiVaults
    EnumerableSet.AddressSet private _allowedMultiVaults;

    /// @notice A buffer provided during claims to handle a situation where
    ///         the actual claimed amount is less than claimed amount reported by the vault,
    ///         which can happen due to rounding errors or stETH rebasing math.
    uint256 public constant MAX_ASSETS_BUFFER = 100;

    constructor(address _creditManager, address _claimer) AbstractAdapter(_creditManager, _claimer) {}

    /// @notice Accepts transferred pending assets in the MultiVault for the credit account
    /// @dev During a MultiVault rebalance, a withdrawal request may end up with some withdrawal indices
    ///      in a transferred state. In order to correctly reflect the in `pendingAssetsOf()`, these
    ///      transfers need to be accepted, so this call must always be coupled with a withdrawal request.
    function multiAccept(address multiVault, uint256[] calldata subvaultIndices, uint256[][] calldata indices)
        external
        creditFacadeOnly
        returns (bool)
    {
        if (!_allowedMultiVaults.contains(multiVault)) revert MultiVaultNotAllowedException();
        _execute(
            abi.encodeCall(IMellowClaimer.multiAcceptAndClaim, (multiVault, subvaultIndices, indices, address(0), 0))
        );
        return false;
    }

    /// @notice Accepts all transferred pending assets, and claims all claimable withdrawals.
    function multiAcceptAndClaim(
        address multiVault,
        uint256[] calldata subvaultIndices,
        uint256[][] calldata indices,
        address,
        uint256 maxAssets
    ) external creditFacadeOnly returns (bool) {
        if (!_allowedMultiVaults.contains(multiVault)) revert MultiVaultNotAllowedException();

        address creditAccount = _creditAccount();
        _claim(multiVault, subvaultIndices, indices, creditAccount, maxAssets);
        return false;
    }

    /// @notice Claims mature withdrawals, represented by the corresponding phantom token
    function withdrawPhantomToken(address stakedPhantomToken, uint256 amount)
        external
        creditFacadeOnly
        returns (bool)
    {
        address multiVault = phantomTokenToMultiVault[stakedPhantomToken];

        if (!_allowedMultiVaults.contains(multiVault)) revert MultiVaultNotAllowedException();

        address creditAccount = _creditAccount();

        (uint256[] memory subvaultIndices, uint256[][] memory indices) =
            getUserSubvaultIndices(multiVault, creditAccount);

        _claim(multiVault, subvaultIndices, indices, creditAccount, amount);

        return false;
    }

    /// @dev It's not possible to deposit from underlying (the vault's asset) into the withdrawal phantom token,
    ///      hence the function is not implemented.
    function depositPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    /// @dev Internal implementation for claims.
    /// @dev Withdrawals from Mellow MultiVaults may return slightly less than maxAssets, due to rounding errors or
    ///      stETH rebasing math. A buffer of 100 units should be sufficient for most cases.
    function _claim(
        address multiVault,
        uint256[] memory subvaultIndices,
        uint256[][] memory indices,
        address creditAccount,
        uint256 maxAssets
    ) internal {
        address asset = IERC4626(multiVault).asset();

        uint256 assetBalanceBefore = IERC20(asset).balanceOf(creditAccount);
        _execute(
            abi.encodeCall(
                IMellowClaimer.multiAcceptAndClaim, (multiVault, subvaultIndices, indices, creditAccount, maxAssets)
            )
        );

        if (maxAssets < MAX_ASSETS_BUFFER) return;
        maxAssets -= MAX_ASSETS_BUFFER;

        uint256 assetBalanceAfter = IERC20(asset).balanceOf(creditAccount);
        if (assetBalanceAfter - assetBalanceBefore < maxAssets) {
            revert InsufficientClaimedException();
        }
    }

    /// @dev Helper function to get the subvault indices and relevant withdrawal indices that belong to a multiVault.
    /// @dev If a withdrawal is requested during a rebalance, some withdrawals may arrive in a transferred state, since the vault
    ///      covers the user's withdrawal with its own pending withdrawals.
    function getMultiVaultSubvaultIndices(address multiVault)
        public
        view
        returns (uint256[] memory subvaultIndices, uint256[][] memory withdrawalIndices)
    {
        return getUserSubvaultIndices(multiVault, multiVault);
    }

    /// @dev Helper function to get the subvault indices and relevant withdrawal indices that belong to a user.
    function getUserSubvaultIndices(address multiVault, address user)
        public
        view
        returns (uint256[] memory subvaultIndices, uint256[][] memory withdrawalIndices)
    {
        uint256 subvaultCount = IMellowMultiVault(multiVault).subvaultsCount();
        subvaultIndices = new uint256[](subvaultCount);
        withdrawalIndices = new uint256[][](subvaultCount);

        for (uint256 i = 0; i < subvaultCount; i++) {
            Subvault memory subvault = IMellowMultiVault(multiVault).subvaultAt(i);
            subvaultIndices[i] = i;
            if (subvault.protocol == MellowProtocol.EIGEN_LAYER) {
                (, withdrawalIndices[i],) = IEigenLayerWithdrawalQueue(subvault.withdrawalQueue).getAccountData({
                    account: user,
                    withdrawalsLimit: type(uint256).max,
                    withdrawalsOffset: 0,
                    transferredWithdrawalsLimit: 0,
                    transferredWithdrawalsOffset: 0
                });
            }
        }
    }

    /// @notice Returns the list of allowed multiVaults
    function allowedMultiVaults() public view returns (address[] memory) {
        return _allowedMultiVaults.values();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, allowedMultiVaults());
    }

    /// @notice Sets the allowed status for a batch of multiVaults.
    function setMultiVaultStatusBatch(MellowMultiVaultStatus[] calldata multiVaults) external configuratorOnly {
        uint256 len = multiVaults.length;
        for (uint256 i; i < len; ++i) {
            if (multiVaults[i].allowed) {
                address asset = IMellowMultiVault(multiVaults[i].multiVault).asset();

                _getMaskOrRevert(multiVaults[i].stakedPhantomToken);
                _getMaskOrRevert(asset);

                (address claimer, address underlying) =
                    MellowWithdrawalPhantomToken(multiVaults[i].stakedPhantomToken).getPhantomTokenInfo();

                if (claimer != targetContract || underlying != asset) revert InvalidStakedPhantomTokenException();

                address vault = MellowWithdrawalPhantomToken(multiVaults[i].stakedPhantomToken).multiVault();

                if (vault != multiVaults[i].multiVault) revert InvalidMultiVaultException();
                _allowedMultiVaults.add(multiVaults[i].multiVault);
                phantomTokenToMultiVault[multiVaults[i].stakedPhantomToken] = multiVaults[i].multiVault;
            } else {
                _allowedMultiVaults.remove(multiVaults[i].multiVault);
            }
        }
    }
}
