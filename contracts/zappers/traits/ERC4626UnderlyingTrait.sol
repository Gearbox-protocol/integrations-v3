// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {ERC20ZapperBase} from "../ERC20ZapperBase.sol";
import {ZapperBase} from "../ZapperBase.sol";

/// @title  ERC-4626 underlying trait
/// @author Gearbox Foundation
/// @notice Implements tokenIn <-> underlying conversion for zappers with an ERC-4626 vault as pool's underlying token
abstract contract ERC4626UnderlyingTrait is ERC20ZapperBase {
    using SafeERC20 for IERC20;

    /// @dev Vault's asset address
    address internal immutable ASSET;

    /// @notice Constructor
    constructor() {
        ASSET = IERC4626(underlying).asset();
    }

    /// @inheritdoc ZapperBase
    /// @dev Returns vault's asset address
    function tokenIn() public view override returns (address) {
        return ASSET;
    }

    /// @inheritdoc ZapperBase
    function _previewTokenInToUnderlying(uint256 tokenInAmount) internal view override returns (uint256 assets) {
        assets = IERC4626(underlying).previewDeposit(tokenInAmount);
    }

    /// @inheritdoc ZapperBase
    function _previewUnderlyingToTokenIn(uint256 assets)
        internal
        view
        virtual
        override
        returns (uint256 tokenInAmount)
    {
        tokenInAmount = IERC4626(underlying).previewRedeem(assets);
    }

    /// @inheritdoc ZapperBase
    function _tokenInToUnderlying(uint256 tokenInAmount) internal override returns (uint256 assets) {
        IERC20(ASSET).safeTransferFrom(msg.sender, address(this), tokenInAmount);
        assets = IERC4626(underlying).deposit(tokenInAmount, address(this));
    }

    /// @inheritdoc ZapperBase
    function _underlyingToTokenIn(uint256 assets, address receiver)
        internal
        virtual
        override
        returns (uint256 tokenInAmount)
    {
        tokenInAmount = IERC4626(underlying).redeem(assets, receiver, address(this));
    }
}

