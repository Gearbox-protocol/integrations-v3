// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IStateSerializer} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IStateSerializer.sol";
import {ERC4626Adapter} from "../erc4626/ERC4626Adapter.sol";
import {IERC4626Adapter} from "../../interfaces/erc4626/IERC4626Adapter.sol";
import {IMellowMultiVault} from "../../integrations/mellow/IMellowMultiVault.sol";
import {IMellow4626VaultAdapter} from "../../interfaces/mellow/IMellow4626VaultAdapter.sol";
import {MellowWithdrawalPhantomToken} from "../../helpers/mellow/MellowWithdrawalPhantomToken.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Mellow ERC4626 Vault adapter
/// @notice Implements logic allowing CAs to interact with Mellow ERC4626 multivauts
contract Mellow4626VaultAdapter is ERC4626Adapter, IMellow4626VaultAdapter {
    uint256 public constant override(ERC4626Adapter, IVersion) version = 3_12;
    bytes32 public constant override(ERC4626Adapter, IVersion) contractType = "ADAPTER::MELLOW_ERC4626_VAULT";

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault ERC4626 vault address
    /// @param _stakedPhantomToken Staked phantom token address
    constructor(address _creditManager, address _vault, address _stakedPhantomToken)
        ERC4626Adapter(_creditManager, _vault, address(0))
    {
        _getMaskOrRevert(_stakedPhantomToken);
        address vault = MellowWithdrawalPhantomToken(_stakedPhantomToken).multivault();
        if (vault != _vault) revert InvalidMultivaultException();
    }

    /// @dev Deposits the asset into the Mellow vault. This is overridden to check whether the Mellow vault
    ///      has enabled deposits through a wrapper only.
    function _deposit(address creditAccount, uint256 assets) internal override returns (bool) {
        if (IMellowMultiVault(targetContract).depositWhitelist()) revert DepositsWhitelistedException();
        super._deposit(creditAccount, assets);
        return false;
    }

    /// @dev Mints the shares of the Mellow vault. This is overridden to check whether the Mellow vault
    ///      has enabled deposits through a wrapper only.
    function _mint(address creditAccount, uint256 shares) internal override returns (bool) {
        if (IMellowMultiVault(targetContract).depositWhitelist()) revert DepositsWhitelistedException();
        super._mint(creditAccount, shares);
        return false;
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

    function serialize()
        external
        view
        virtual
        override(ERC4626Adapter, IStateSerializer)
        returns (bytes memory serializedData)
    {
        serializedData = abi.encode(creditManager, targetContract, asset);
    }
}
