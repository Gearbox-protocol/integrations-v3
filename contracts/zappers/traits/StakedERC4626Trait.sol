// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IFarmingPool} from "@1inch/farming/contracts/interfaces/IFarmingPool.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ERC20ZapperBase} from "../ERC20ZapperBase.sol";
import {ZapperBase} from "../ZapperBase.sol";

/// @title Staked ERC-4626 trait
/// @notice Implements tokenIn -> underlying conversion for zappers with an ERC-4626 vault
///         staked in 1inch farming pool as input token
abstract contract StakedERC4626Trait is ERC20ZapperBase {
    using Address for address;
    using SafeERC20 for IERC20;

    /// @notice Thrown when the vault's asset does not match the zapper's underlying token
    error IncompatibleAssetException();

    /// @notice 1inch farming pool address
    address public immutable farmingPool;

    /// @notice Vault address
    address public immutable vault;

    /// @notice Constructor
    /// @param farmingPool_ Farming pool address
    /// @dev Reverts if the vault's asset does not match the zapper's underlying token
    constructor(address farmingPool_) {
        farmingPool = farmingPool_;
        vault = _getStakedToken(farmingPool_);
        if (IERC4626(vault).asset() != underlying) revert IncompatibleAssetException();
    }

    /// @inheritdoc ZapperBase
    /// @dev Returns farming pool address
    function tokenIn() public view override returns (address) {
        return farmingPool;
    }

    /// @inheritdoc ZapperBase
    function _previewTokenInToUnderlying(uint256 tokenInAmount) internal view override returns (uint256 assets) {
        assets = IERC4626(vault).previewRedeem(tokenInAmount);
    }

    /// @inheritdoc ZapperBase
    /// @dev Reverts as moving funds back to the farming pool is not supported
    function _previewUnderlyingToTokenIn(uint256) internal pure override returns (uint256) {
        revert NotImplementedException();
    }

    /// @inheritdoc ZapperBase
    function _tokenInToUnderlying(uint256 tokenInAmount) internal override returns (uint256 assets) {
        IERC20(farmingPool).safeTransferFrom(msg.sender, address(this), tokenInAmount);
        IFarmingPool(farmingPool).withdraw(tokenInAmount);
        assets = IERC4626(vault).redeem(tokenInAmount, address(this), address(this));
    }

    /// @inheritdoc ZapperBase
    /// @dev Reverts as moving funds back to the farming pool is not supported
    function _underlyingToTokenIn(uint256, address) internal pure override returns (uint256) {
        revert NotImplementedException();
    }

    /// @dev Returns the staked token of the farming pool
    function _getStakedToken(address farmingPool_) internal view returns (address) {
        bytes memory result = farmingPool_.functionStaticCall(abi.encodeWithSignature("stakingToken()"));
        return abi.decode(result, (address));
    }
}
