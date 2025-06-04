// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ERC20ZapperBase} from "../ERC20ZapperBase.sol";
import {ZapperBase} from "../ZapperBase.sol";

/// @title ERC-4626 trait
/// @notice Implements tokenIn -> underlying conversion for zappers with an ERC-4626 vault as input token
abstract contract ERC4626Trait is ERC20ZapperBase {
    using SafeERC20 for IERC20;

    /// @notice Thrown when the vault's asset does not match the zapper's underlying token
    error IncompatibleAssetException();

    /// @notice Vault address
    address public immutable vault;

    /// @notice Constructor
    /// @param vault_ Vault address
    constructor(address vault_) {
        vault = vault_;
        if (IERC4626(vault).asset() != underlying) revert IncompatibleAssetException();
    }

    /// @inheritdoc ZapperBase
    /// @dev Returns vault address
    function tokenIn() public view override returns (address) {
        return vault;
    }

    /// @inheritdoc ZapperBase
    function _previewTokenInToUnderlying(uint256 tokenInAmount) internal view override returns (uint256 assets) {
        assets = IERC4626(vault).previewRedeem(tokenInAmount);
    }

    /// @inheritdoc ZapperBase
    /// @dev Reverts as moving funds back to the vault is not supported
    function _previewUnderlyingToTokenIn(uint256) internal pure override returns (uint256) {
        revert NotImplementedException();
    }

    /// @inheritdoc ZapperBase
    function _tokenInToUnderlying(uint256 tokenInAmount) internal override returns (uint256 assets) {
        IERC20(vault).safeTransferFrom(msg.sender, address(this), tokenInAmount);
        assets = IERC4626(vault).redeem(tokenInAmount, address(this), address(this));
    }

    /// @inheritdoc ZapperBase
    /// @dev Reverts as moving funds back to the vault is not supported
    function _underlyingToTokenIn(uint256, address) internal pure override returns (uint256) {
        revert NotImplementedException();
    }
}
