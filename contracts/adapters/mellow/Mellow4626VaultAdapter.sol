// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC4626Adapter} from "../erc4626/ERC4626Adapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Mellow ERC4626 Vault adapter
/// @notice Implements logic allowing CAs to interact with a ERC4626 vaults, but with `withdraw` / `redeem` restricted, to avoid
///         CA's being exposed to Mellow's asynchronous withdrawals
contract Mellow4626VaultAdapter is ERC4626Adapter {
    function _gearboxAdapterType() external pure virtual override returns (AdapterType) {
        return AdapterType.MELLOW_ERC4626_VAULT;
    }

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault ERC4626 vault address
    constructor(address _creditManager, address _vault) ERC4626Adapter(_creditManager, _vault) {}

    /// @dev For Mellow ERC4626 vaults all withdrawals revert to avoid CA's interacting with Mellow's delayed withdrawals
    function withdraw(uint256 assets, address, address)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        revert NotImplementedException();
    }

    /// @dev For Mellow ERC4626 vaults all withdrawals revert to avoid CA's interacting with Mellow's delayed withdrawals
    function redeem(uint256 shares, address, address)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        revert NotImplementedException();
    }

    /// @dev For Mellow ERC4626 vaults all withdrawals revert to avoid CA's interacting with Mellow's delayed withdrawals
    function redeemDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        revert NotImplementedException();
    }
}
