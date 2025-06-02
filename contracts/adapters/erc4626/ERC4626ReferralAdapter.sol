// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IStateSerializer} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IStateSerializer.sol";
import {ERC4626Adapter} from "../erc4626/ERC4626Adapter.sol";
import {IERC4626Referral} from "../../integrations/erc4626/IERC4626Referral.sol";

/// @title Mellow ERC4626 Vault adapter
/// @notice Implements logic allowing CAs to interact with a ERC4626 vaults, but with `withdraw` / `redeem` restricted, to avoid
///         CA's being exposed to Mellow's asynchronous withdrawals
contract ERC4626ReferralAdapter is ERC4626Adapter {
    uint256 public constant override version = 3_11;
    bytes32 public constant override contractType = "ADAPTER::ERC4626_VAULT_REFERRAL";

    uint16 public immutable referral;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault ERC4626 vault address
    constructor(address _creditManager, address _vault, uint16 _referral) ERC4626Adapter(_creditManager, _vault) {
        referral = _referral;
    }

    function _deposit(address creditAccount, uint256 assets) internal override {
        _executeSwapSafeApprove(asset, abi.encodeCall(IERC4626Referral.deposit, (assets, creditAccount, referral)));
    }

    function _mint(address creditAccount, uint256 shares) internal override {
        _executeSwapSafeApprove(asset, abi.encodeCall(IERC4626Referral.mint, (shares, creditAccount, referral)));
    }

    function serialize() external view virtual override returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, asset, referral);
    }
}
