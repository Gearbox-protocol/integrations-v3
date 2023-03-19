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
        if (address(_aToken) == address(0)) revert ZeroAddressException();

        aToken = _aToken;
        underlying = IERC20(aToken.UNDERLYING_ASSET_ADDRESS());
        lendingPool = aToken.POOL();
        _normalizedIncome = lendingPool.getReserveNormalizedIncome(address(underlying));
        underlying.safeApprove(address(lendingPool), type(uint256).max);
    }

    /// @notice waToken decimals, same as underlying and aToken
    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return aToken.decimals();
    }

    /// @inheritdoc IWrappedAToken
    function balanceOfUnderlying(address account) external view override returns (uint256) {
        return (balanceOf(account) * exchangeRate()) / WAD;
    }

    /// @inheritdoc IWrappedAToken
    function exchangeRate() public view override returns (uint256) {
        return WAD * lendingPool.getReserveNormalizedIncome(address(underlying)) / _normalizedIncome;
    }

    /// @inheritdoc IWrappedAToken
    function deposit(uint256 assets) external override returns (uint256 shares) {
        aToken.transferFrom(msg.sender, address(this), assets);
        shares = _deposit(assets);
    }

    /// @inheritdoc IWrappedAToken
    function depositUnderlying(uint256 assets) external override returns (uint256 shares) {
        underlying.safeTransferFrom(msg.sender, address(this), assets);
        _ensureAllowance(assets);
        lendingPool.deposit(address(underlying), assets, address(this), 0);
        shares = _deposit(assets);
    }

    /// @inheritdoc IWrappedAToken
    function withdraw(uint256 shares) external override returns (uint256 assets) {
        assets = _withdraw(shares);
        aToken.transfer(msg.sender, assets);
    }

    /// @inheritdoc IWrappedAToken
    function withdrawUnderlying(uint256 shares) external override returns (uint256 assets) {
        assets = _withdraw(shares);
        lendingPool.withdraw(address(underlying), assets, msg.sender);
    }

    /// @dev Internal implementation of deposit
    function _deposit(uint256 assets) internal returns (uint256 shares) {
        shares = (assets * WAD) / exchangeRate();
        _mint(msg.sender, shares);
        emit Deposit(msg.sender, assets, shares);
    }

    /// @dev Internal implementation of withdraw
    function _withdraw(uint256 shares) internal returns (uint256 assets) {
        assets = (shares * exchangeRate()) / WAD;
        _burn(msg.sender, shares);
        emit Withdraw(msg.sender, assets, shares);
    }

    /// @dev Gives lending pool max approval for underlying if it falls below `amount`
    function _ensureAllowance(uint256 amount) internal {
        if (underlying.allowance(address(this), address(lendingPool)) < amount) {
            underlying.safeApprove(address(lendingPool), type(uint256).max);
        }
    }
}
