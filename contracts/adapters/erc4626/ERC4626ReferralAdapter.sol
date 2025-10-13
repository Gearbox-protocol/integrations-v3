// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {ERC4626Adapter} from "../erc4626/ERC4626Adapter.sol";
import {IERC4626Referral} from "../../integrations/erc4626/IERC4626Referral.sol";

/// @title ERC4626 Vault Referral adapter
/// @notice Same as `ERC4626Adapter`, but uses a signature for deposits that allows deployer to specify the referral code
contract ERC4626ReferralAdapter is ERC4626Adapter {
    uint16 public immutable referral;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault ERC4626 vault address
    /// @param _referral Referral code
    constructor(address _creditManager, address _vault, uint16 _referral)
        ERC4626Adapter(_creditManager, _vault, address(0))
    {
        referral = _referral;
    }

    function version() external pure virtual override returns (uint256) {
        return 3_10;
    }

    function contractType() external pure virtual override returns (bytes32) {
        return "ADAPTER::ERC4626_VAULT_REFERRAL";
    }

    function serialize() external view virtual override returns (bytes memory) {
        return abi.encode(creditManager, targetContract, asset, referral);
    }

    function _deposit(address creditAccount, uint256 assets) internal virtual override returns (bool) {
        _executeSwapSafeApprove(asset, abi.encodeCall(IERC4626Referral.deposit, (assets, creditAccount, referral)));
        return false;
    }

    function _mint(address creditAccount, uint256 shares) internal virtual override returns (bool) {
        _executeSwapSafeApprove(asset, abi.encodeCall(IERC4626Referral.mint, (shares, creditAccount, referral)));
        return false;
    }
}
