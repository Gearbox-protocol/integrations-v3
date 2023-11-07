// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {IPoolService} from "@gearbox-protocol/core-v2/contracts/interfaces/IPoolService.sol";
import {
    IncompatibleContractException,
    NotImplementedException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {ERC20ZapperBase} from "../ERC20ZapperBase.sol";
import {ZapperBase} from "../ZapperBase.sol";

/// @title dToken trait
/// @notice Implements tokenIn -> underlying conversion for pools with older diesel tokens as input tokens
abstract contract DTokenTrait is ERC20ZapperBase {
    using SafeERC20 for IERC20;

    /// @dev Old pool address
    address internal immutable _pool;

    /// @dev Old diesel token address
    address internal immutable _dToken;

    /// @notice Constructor
    /// @param pool Old pool address
    constructor(address pool) {
        if (IPoolService(pool).underlyingToken() != underlying) revert IncompatibleContractException();
        _pool = pool;
        _dToken = IPoolService(pool).dieselToken();
    }

    /// @inheritdoc ZapperBase
    /// @dev Returns older pool's diesel token address
    function tokenIn() public view override returns (address) {
        return _dToken;
    }

    /// @inheritdoc ZapperBase
    function _previewTokenInToUnderlying(uint256 tokenInAmount) internal view override returns (uint256 assets) {
        assets = IPoolService(_pool).fromDiesel(tokenInAmount);
    }

    /// @inheritdoc ZapperBase
    /// @dev Reverts as conversion back to older diesel tokens is not supported
    function _previewUnderlyingToTokenIn(uint256) internal pure override returns (uint256) {
        revert NotImplementedException();
    }

    /// @inheritdoc ZapperBase
    function _tokenInToUnderlying(uint256 tokenInAmount) internal override returns (uint256 assets) {
        IERC20(_dToken).safeTransferFrom(msg.sender, address(this), tokenInAmount);
        assets = IPoolService(_pool).removeLiquidity(tokenInAmount, address(this));
    }

    /// @inheritdoc ZapperBase
    /// @dev Reverts as conversion back to older diesel tokens is not supported
    function _underlyingToTokenIn(uint256, address) internal pure override returns (uint256) {
        revert NotImplementedException();
    }
}
