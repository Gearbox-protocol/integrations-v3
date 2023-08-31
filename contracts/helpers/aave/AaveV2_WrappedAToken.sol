// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

import {IAToken} from "../../integrations/aave/IAToken.sol";
import {ILendingPool} from "../../integrations/aave/ILendingPool.sol";

interface IWrappedATokenEvents {
    /// @notice Emitted on deposit
    /// @param account Account that performed deposit
    /// @param assets Amount of deposited aTokens
    /// @param shares Amount of waTokens minted to account
    event Deposit(address indexed account, uint256 assets, uint256 shares);

    /// @notice Emitted on withdrawal
    /// @param account Account that performed withdrawal
    /// @param assets Amount of withdrawn aTokens
    /// @param shares Amount of waTokens burnt from account
    event Withdraw(address indexed account, uint256 assets, uint256 shares);
}

/// @title Wrapped aToken
/// @notice Non-rebasing wrapper of Aave V2 aToken
/// @dev Ignores any Aave incentives
contract WrappedAToken is ERC20, SanityCheckTrait, IWrappedATokenEvents {
    using SafeERC20 for ERC20;

    /// @notice Underlying aToken
    address public immutable aToken;

    /// @notice Underlying token
    address public immutable underlying;

    /// @notice Aave lending pool
    address public immutable lendingPool;

    /// @dev aToken's normalized income (aka interest accumulator) at the moment of waToken creation
    uint256 private immutable _normalizedIncome;

    /// @dev waToken decimals
    uint8 private immutable _decimals;

    /// @notice Constructor
    /// @param _aToken Underlying aToken address
    constructor(address _aToken)
        ERC20(
            address(_aToken) != address(0) ? string(abi.encodePacked("Wrapped ", ERC20(_aToken).name())) : "",
            address(_aToken) != address(0) ? string(abi.encodePacked("w", ERC20(_aToken).symbol())) : ""
        )
        nonZeroAddress(_aToken) // U:[WAT-1]
    {
        aToken = _aToken; // U:[WAT-2]
        underlying = IAToken(aToken).UNDERLYING_ASSET_ADDRESS(); // U:[WAT-2]
        lendingPool = address(IAToken(aToken).POOL()); // U:[WAT-2]
        _normalizedIncome = ILendingPool(lendingPool).getReserveNormalizedIncome(underlying);
        _decimals = IAToken(aToken).decimals(); // U:[WAT-2]
        ERC20(underlying).approve(lendingPool, type(uint256).max);
    }

    /// @notice waToken decimals, same as underlying and aToken
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Returns amount of aTokens belonging to given account (increases as interest is accrued)
    function balanceOfUnderlying(address account) external view returns (uint256) {
        return balanceOf(account) * exchangeRate() / WAD; // U:[WAT-3]
    }

    /// @notice Returns amount of aTokens per waToken, scaled by 1e18
    function exchangeRate() public view returns (uint256) {
        return WAD * ILendingPool(lendingPool).getReserveNormalizedIncome(underlying) / _normalizedIncome; // U:[WAT-4]
    }

    /// @notice Deposit given amount of aTokens (aToken must be approved before the call)
    /// @param assets Amount of aTokens to deposit in exchange for waTokens
    /// @return shares Amount of waTokens minted to the caller
    function deposit(uint256 assets) external returns (uint256 shares) {
        ERC20(aToken).transferFrom(msg.sender, address(this), assets);
        shares = _deposit(assets); // U:[WAT-5]
    }

    /// @notice Deposit given amount underlying tokens (underlying must be approved before the call)
    /// @param assets Amount of underlying tokens to deposit in exchange for waTokens
    /// @return shares Amount of waTokens minted to the caller
    function depositUnderlying(uint256 assets) external returns (uint256 shares) {
        ERC20(underlying).safeTransferFrom(msg.sender, address(this), assets);
        _ensureAllowance(assets);
        ILendingPool(lendingPool).deposit(underlying, assets, address(this), 0); // U:[WAT-6]
        shares = _deposit(assets); // U:[WAT-6]
    }

    /// @notice Withdraw given amount of waTokens for aTokens
    /// @param shares Amount of waTokens to burn in exchange for aTokens
    /// @return assets Amount of aTokens sent to the caller
    function withdraw(uint256 shares) external returns (uint256 assets) {
        assets = _withdraw(shares); // U:[WAT-7]
        ERC20(aToken).transfer(msg.sender, assets);
    }

    /// @notice Withdraw given amount of waTokens for underlying tokens
    /// @param shares Amount of waTokens to burn in exchange for underlying tokens
    /// @return assets Amount of underlying tokens sent to the caller
    function withdrawUnderlying(uint256 shares) external returns (uint256 assets) {
        assets = _withdraw(shares); // U:[WAT-8]
        ILendingPool(lendingPool).withdraw(underlying, assets, msg.sender); // U:[WAT-8]
    }

    /// @dev Internal implementation of deposit
    function _deposit(uint256 assets) internal returns (uint256 shares) {
        shares = assets * WAD / exchangeRate();
        _mint(msg.sender, shares); // U:[WAT-5,6]
        emit Deposit(msg.sender, assets, shares); // U:[WAT-5,6]
    }

    /// @dev Internal implementation of withdraw
    function _withdraw(uint256 shares) internal returns (uint256 assets) {
        assets = shares * exchangeRate() / WAD;
        _burn(msg.sender, shares); // U:[WAT-7,8]
        emit Withdraw(msg.sender, assets, shares); // U:[WAT-7,8]
    }

    /// @dev Gives lending pool max approval for underlying if it falls below `amount`
    function _ensureAllowance(uint256 amount) internal {
        if (ERC20(underlying).allowance(address(this), lendingPool) < amount) {
            ERC20(underlying).approve(lendingPool, type(uint256).max); // [WAT-9]
        }
    }
}
