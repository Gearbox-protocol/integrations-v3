// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {IFarmingPool} from "@1inch/farming/contracts/interfaces/IFarmingPool.sol";
import {ZapperBase} from "../ZapperBase.sol";

/// @title Farming mixin
/// @dev Implements shares <-> tokenOut conversion functions for zappers that stake shares in 1inch `FarmingPool` contract
abstract contract FarmingMixin is ZapperBase {
    using SafeERC20 for IERC20;

    /// @dev Farming pool to stake shares at
    address internal immutable _farmingPool;

    /// @notice Constructor
    /// @param farmingPool Farming pool to stake shares at
    constructor(address farmingPool) {
        _farmingPool = farmingPool;
        _resetAllowance(pool, farmingPool);
    }

    /// @inheritdoc ZapperBase
    /// @dev Returns farming pool address
    function tokenOut() public view override returns (address) {
        return _farmingPool;
    }

    /// @inheritdoc ZapperBase
    /// @dev Returns `shares` since farming pool balance is the same as staked amount
    function _previewSharesToTokenOut(uint256 shares) internal pure override returns (uint256 tokenOutAmount) {
        tokenOutAmount = shares;
    }

    /// @inheritdoc ZapperBase
    /// @dev Returns `tokenOutAmount` since farming pool balance is the same as staked amount
    function _previewTokenOutToShares(uint256 tokenOutAmount) internal pure override returns (uint256 shares) {
        shares = tokenOutAmount;
    }

    /// @inheritdoc ZapperBase
    /// @dev Returns `shares` since farming pool balance is the same as staked amount
    function _sharesToTokenOut(uint256 shares, address receiver) internal override returns (uint256 tokenOutAmount) {
        IFarmingPool(_farmingPool).deposit(shares);
        tokenOutAmount = shares;
        IERC20(_farmingPool).safeTransfer(receiver, tokenOutAmount);
    }

    /// @inheritdoc ZapperBase
    /// @dev Returns `tokenOutAmount` since farming pool balance is the same as staked amount
    function _tokenOutToShares(uint256 tokenOutAmount, address owner) internal override returns (uint256 shares) {
        IERC20(_farmingPool).safeTransferFrom(owner, address(this), tokenOutAmount);
        IFarmingPool(_farmingPool).withdraw(tokenOutAmount);
        shares = tokenOutAmount;
    }
}
