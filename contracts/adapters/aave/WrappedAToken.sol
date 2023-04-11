// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {IAToken} from "../../integrations/aave/IAToken.sol";
import {ILendingPool} from "../../integrations/aave/ILendingPool.sol";
import {IWrappedAToken} from "../../interfaces/aave/IWrappedAToken.sol";

/// @title Wrapped aToken
/// @notice Non-rebasing wrapper of Aave V2 aToken
/// @dev Ignores any Aave incentives
contract WrappedAToken is ERC20, IWrappedAToken {
    using SafeERC20 for IERC20;

    /// @inheritdoc IWrappedAToken
    IAToken public immutable override aToken;

    /// @inheritdoc IWrappedAToken
    IERC20 public immutable override underlying;

    /// @inheritdoc IWrappedAToken
    ILendingPool public immutable override lendingPool;

    /// @dev aToken's normalized income (aka interest accumulator) at the moment of waToken creation
    uint256 private immutable _normalizedIncome;

    /// @notice Constructor
    /// @param _aToken Underlying aToken
    constructor(IAToken _aToken)
        ERC20(
            address(_aToken) != address(0) ? string(abi.encodePacked("Wrapped ", _aToken.name())) : "",
            address(_aToken) != address(0) ? string(abi.encodePacked("w", _aToken.symbol())) : ""
        )
    {
        if (address(_aToken) == address(0)) revert ZeroAddressException(); // F: [WAT-1]

        aToken = _aToken; // F: [WAT-2]
        underlying = IERC20(aToken.UNDERLYING_ASSET_ADDRESS()); // F: [WAT-2]
        lendingPool = aToken.POOL(); // F: [WAT-2]
        _normalizedIncome = lendingPool.getReserveNormalizedIncome(address(underlying));
        underlying.approve(address(lendingPool), type(uint256).max);
    }

    /// @notice waToken decimals, same as underlying and aToken
    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return aToken.decimals(); // F: [WAT-2]
    }

    /// @inheritdoc IWrappedAToken
    function balanceOfUnderlying(address account) external view override returns (uint256) {
        return (balanceOf(account) * exchangeRate()) / WAD; // F: [WAT-3]
    }

    /// @inheritdoc IWrappedAToken
    function exchangeRate() public view override returns (uint256) {
        return WAD * lendingPool.getReserveNormalizedIncome(address(underlying)) / _normalizedIncome; // F: [WAT-4]
    }

    /// @inheritdoc IWrappedAToken
    function deposit(uint256 assets) external override returns (uint256 shares) {
        aToken.transferFrom(msg.sender, address(this), assets);
        shares = _deposit(assets); // F: [WAT-5]
    }

    /// @inheritdoc IWrappedAToken
    function depositUnderlying(uint256 assets) external override returns (uint256 shares) {
        underlying.safeTransferFrom(msg.sender, address(this), assets);
        _ensureAllowance(assets);
        lendingPool.deposit(address(underlying), assets, address(this), 0); // F: [WAT-6]
        shares = _deposit(assets); // F: [WAT-6]
    }

    /// @inheritdoc IWrappedAToken
    function withdraw(uint256 shares) external override returns (uint256 assets) {
        assets = _withdraw(shares); // F: [WAT-7]
        aToken.transfer(msg.sender, assets);
    }

    /// @inheritdoc IWrappedAToken
    function withdrawUnderlying(uint256 shares) external override returns (uint256 assets) {
        assets = _withdraw(shares); // F: [WAT-8]
        lendingPool.withdraw(address(underlying), assets, msg.sender); // F: [WAT-8]
    }

    /// @dev Internal implementation of deposit
    function _deposit(uint256 assets) internal returns (uint256 shares) {
        shares = (assets * WAD) / exchangeRate();
        _mint(msg.sender, shares); // F: [WAT-5, WAT-6]
        emit Deposit(msg.sender, assets, shares); // F: [WAT-5, WAT-6]
    }

    /// @dev Internal implementation of withdraw
    function _withdraw(uint256 shares) internal returns (uint256 assets) {
        assets = (shares * exchangeRate()) / WAD;
        _burn(msg.sender, shares); // F: [WAT-7, WAT-8]
        emit Withdraw(msg.sender, assets, shares); // F: [WAT-7, WAT-8]
    }

    /// @dev Gives lending pool max approval for underlying if it falls below `amount`
    function _ensureAllowance(uint256 amount) internal {
        if (underlying.allowance(address(this), address(lendingPool)) < amount) {
            underlying.approve(address(lendingPool), type(uint256).max); // [WAT-9]
        }
    }
}
