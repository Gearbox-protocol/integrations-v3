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
import {IMellowClaimerAdapter, MellowMultivaultStatus} from "../../interfaces/mellow/IMellowClaimerAdapter.sol";
import {MellowWithdrawalPhantomToken} from "../../helpers/mellow/MellowWithdrawalPhantomToken.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Mellow Claimer adapter
/// @notice Implements logic allowing CAs to interact with a Mellow Claimer, which allows them to claim mature withdrawals.
contract MellowClaimerAdapter is AbstractAdapter, IMellowClaimerAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::MELLOW_CLAIMER";
    uint256 public constant override version = 3_10;

    /// @notice Maps a staked phantom token to the multivault it represents
    mapping(address stakedPhantomToken => address multivault) public phantomTokenToMultivault;

    /// @notice Set of allowed multivaults
    EnumerableSet.AddressSet private _allowedMultivaults;

    constructor(address _creditManager, address _claimer) AbstractAdapter(_creditManager, _claimer) {}

    /// @notice Accepts transferred pending assets in the Multivault for the credit account
    /// @dev During a MultiVault rebalance, a withdrawal request may end up with some withdrawal indices
    ///      in a transferred state. In order to correctly reflect the in pendingAssetsOf(), these
    ///      transfers need to be accepted, so this call must always be coupled with a withdrawal request.
    function multiAccept(address multiVault, uint256[] calldata subvaultIndices, uint256[][] calldata indices)
        external
        creditFacadeOnly
        returns (bool)
    {
        if (!_allowedMultivaults.contains(multiVault)) revert MultivaultNotAllowedException();
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
        if (!_allowedMultivaults.contains(multiVault)) revert MultivaultNotAllowedException();
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
        address creditAccount = _creditAccount();

        address multivault = phantomTokenToMultivault[stakedPhantomToken];
        if (!_allowedMultivaults.contains(multivault)) {
            revert MultivaultNotAllowedException();
        }

        (uint256[] memory subvaultIndices, uint256[][] memory indices) = getSubvaultIndices(multivault);

        _claim(multivault, subvaultIndices, indices, creditAccount, amount);

        return false;
    }

    /// @dev It's not possible to deposit from underlying (the vault's asset) into the withdrawal phantom token,
    ///      hence the function is not implemented.
    function depositPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    /// @dev Internal implementation for claims.
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
        uint256 assetBalanceAfter = IERC20(asset).balanceOf(creditAccount);
        if (assetBalanceAfter - assetBalanceBefore < maxAssets) revert InsufficientClaimedException();
    }

    /// @dev Helper function to get the subvault indices and relevant withdrawal indices for each subvault in a multivault.
    function getSubvaultIndices(address multiVault)
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
                (, withdrawalIndices[i],) = IEigenLayerWithdrawalQueue(subvault.withdrawalQueue).getAccountData(
                    multiVault, 0, type(uint256).max, 0, 0
                );
            }
        }
    }

    /// @notice Returns the list of allowed multivaults
    function allowedMultivaults() public view returns (address[] memory) {
        return _allowedMultivaults.values();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, allowedMultivaults());
    }

    /// @notice Sets the allowed status for a batch of multivaults.
    function setMultivaultStatusBatch(MellowMultivaultStatus[] calldata multivaults) external configuratorOnly {
        uint256 len = multivaults.length;
        for (uint256 i; i < len; ++i) {
            if (multivaults[i].allowed) {
                _getMaskOrRevert(multivaults[i].stakedPhantomToken);
                _getMaskOrRevert(IMellowMultiVault(multivaults[i].multivault).asset());

                address vault = MellowWithdrawalPhantomToken(multivaults[i].stakedPhantomToken).multivault();

                if (vault != multivaults[i].multivault) revert InvalidMultivaultException();
                _allowedMultivaults.add(multivaults[i].multivault);
                phantomTokenToMultivault[multivaults[i].stakedPhantomToken] = multivaults[i].multivault;
            } else {
                _allowedMultivaults.remove(multivaults[i].multivault);
            }
        }
    }
}
