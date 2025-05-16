// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {ERC4626Adapter} from "../erc4626/ERC4626Adapter.sol";
import {IMellowSimpleLRTVault} from "../../integrations/mellow/IMellowSimpleLRTVault.sol";
import {IMellow4626VaultAdapter} from "../../interfaces/mellow/IMellow4626VaultAdapter.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Mellow ERC4626 Vault adapter
/// @notice Implements logic allowing CAs to interact with a ERC4626 vaults, but with `withdraw` / `redeem` restricted, to avoid
///         CA's being exposed to Mellow's asynchronous withdrawals
contract Mellow4626VaultAdapter is ERC4626Adapter, IMellow4626VaultAdapter {
    bytes32 public constant override(ERC4626Adapter, IVersion) contractType = "ADAPTER::MELLOW_ERC4626_VAULT";

    address public immutable stakedPhantomToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault ERC4626 vault address
    constructor(address _creditManager, address _vault, address _stakedPhantomToken)
        ERC4626Adapter(_creditManager, _vault)
    {
        stakedPhantomToken = _stakedPhantomToken;
        _getMaskOrRevert(stakedPhantomToken);
    }

    /// @notice Claims mature withdrawals from the vault
    /// @param maxAmount Amount to claim
    /// @dev `account` and `recipient` are ignored, since they are always set to the credit account address
    function claim(address, address, uint256 maxAmount) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        _execute(abi.encodeCall(IMellowSimpleLRTVault.claim, (creditAccount, creditAccount, maxAmount)));
        return false;
    }

    /// @notice Claims mature withdrawals, represented by the phantom token
    function withdrawPhantomToken(address token, uint256 amount) external override creditFacadeOnly returns (bool) {
        if (token != stakedPhantomToken) revert IncorrectStakedPhantomTokenException();
        address creditAccount = _creditAccount();
        _execute(abi.encodeCall(IMellowSimpleLRTVault.claim, (creditAccount, creditAccount, amount)));
        return false;
    }
}
