// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {ERC4626Adapter} from "../erc4626/ERC4626Adapter.sol";
import {IMellow4626VaultAdapter} from "../../interfaces/mellow/IMellow4626VaultAdapter.sol";
import {MellowWithdrawalPhantomToken} from "../../helpers/mellow/MellowWithdrawalPhantomToken.sol";

/// @title Mellow ERC4626 Vault adapter
/// @notice Implements logic allowing CAs to interact with Mellow ERC4626 MultiVaults
contract Mellow4626VaultAdapter is ERC4626Adapter, IMellow4626VaultAdapter {
    uint256 public constant override(ERC4626Adapter, IVersion) version = 3_12;
    bytes32 public constant override(ERC4626Adapter, IVersion) contractType = "ADAPTER::MELLOW_ERC4626_VAULT";

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault Mellow vault address
    /// @param _stakedPhantomToken Staked phantom token address
    constructor(address _creditManager, address _vault, address _stakedPhantomToken)
        ERC4626Adapter(_creditManager, _vault, address(0))
    {
        _getMaskOrRevert(_stakedPhantomToken);
        address vault_ = MellowWithdrawalPhantomToken(_stakedPhantomToken).multiVault();
        if (vault_ != _vault) revert InvalidMultiVaultException();
    }

    /// @notice Requests a withdrawal from the Mellow vault for given amount of assets
    /// @dev This function is overridden to return `true`, since the withdrawal phantom token should be priced with safe prices
    function _withdraw(address creditAccount, uint256 assets) internal override returns (bool) {
        super._withdraw(creditAccount, assets);
        return true;
    }

    /// @notice Requests a withdrawal from the Mellow vault for given amount of shares
    /// @dev This function is overridden to return `true`, since the withdrawal phantom token should be priced with safe prices
    function _redeem(address creditAccount, uint256 shares) internal override returns (bool) {
        super._redeem(creditAccount, shares);
        return true;
    }
}
