// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {ILendingPool} from "../../integrations/aave/ILendingPool.sol";
import {IAaveV2_LendingPoolAdapter} from "../../interfaces/aave/IAaveV2_LendingPoolAdapter.sol";

/// @title Aave V2 LendingPool adapter
/// @notice Implements logic allowing CAs to interact with Aave's lending pool
contract AaveV2_LendingPoolAdapter is AbstractAdapter, IAaveV2_LendingPoolAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.AAVE_V2_LENDING_POOL;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _lendingPool Lending pool address
    constructor(address _creditManager, address _lendingPool)
        AbstractAdapter(_creditManager, _lendingPool) // U:[AAVE2-1]
    {}

    /// @dev Returns aToken address for given underlying token
    function _aToken(address underlying) internal view returns (address) {
        return ILendingPool(targetContract).getReserveData(underlying).aTokenAddress;
    }

    // -------- //
    // DEPOSITS //
    // -------- //

    /// @notice Deposit underlying tokens into Aave in exchange for aTokens
    /// @param asset Address of underlying token to deposit
    /// @param amount Amount of underlying tokens to deposit
    /// @dev Last two parameters are ignored as `onBehalfOf` can only be credit account,
    ///      and `referralCode` is set to zero
    function deposit(address asset, uint256 amount, address, uint16)
        external
        override
        creditFacadeOnly // U:[AAVE2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[AAVE2-3]
        (tokensToEnable, tokensToDisable) = _deposit(creditAccount, asset, amount, false); // U:[AAVE2-3]
    }

    /// @notice Deposit all underlying tokens into Aave in exchange for aTokens, disables underlying
    /// @param asset Address of underlying token to deposit
    function depositAll(address asset)
        external
        override
        creditFacadeOnly // U:[AAVE2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[AAVE2-4]

        uint256 amount = IERC20(asset).balanceOf(creditAccount); // U:[AAVE2-4]
        if (amount <= 1) return (0, 0);
        unchecked {
            --amount; // U:[AAVE2-4]
        }

        (tokensToEnable, tokensToDisable) = _deposit(creditAccount, asset, amount, true); // U:[AAVE2-4]
    }

    /// @dev Internal implementation of `deposit` and `depositAll` functions
    ///      - using `_executeSwap` because need to check if tokens are recognized by the system
    ///      - underlying is approved before the call because lending pool needs permission to transfer it
    ///      - aToken is enabled after the call
    ///      - underlying is only disabled when depositing the entire balance
    function _deposit(address creditAccount, address asset, uint256 amount, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            asset,
            _aToken(asset),
            abi.encodeCall(ILendingPool.deposit, (asset, amount, creditAccount, 0)),
            disableTokenIn
        ); // U:[AAVE2-3,4]
    }

    // ----------- //
    // WITHDRAWALS //
    // ----------- //

    /// @notice Withdraw underlying tokens from Aave and burn aTokens
    /// @param asset Address of underlying token to deposit
    /// @param amount Amount of underlying tokens to withdraw
    ///        If `type(uint256).max`, will withdraw the full amount
    /// @dev Last parameter is ignored because underlying recepient can only be credit account
    function withdraw(address asset, uint256 amount, address)
        external
        override
        creditFacadeOnly // U:[AAVE2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[AAVE2-5A,5B]
        if (amount == type(uint256).max) {
            (tokensToEnable, tokensToDisable) = _withdrawAll(creditAccount, asset); // U:[AAVE2-5B]
        } else {
            (tokensToEnable, tokensToDisable) = _withdraw(creditAccount, asset, amount); // U:[AAVE2-5A]
        }
    }

    /// @notice Withdraw all underlying tokens from Aave and burn aTokens, disables aToken
    /// @param asset Address of underlying token to withdraw
    function withdrawAll(address asset)
        external
        override
        creditFacadeOnly // U:[AAVE2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[AAVE2-6]
        (tokensToEnable, tokensToDisable) = _withdrawAll(creditAccount, asset); // U:[AAVE2-6]
    }

    /// @dev Internal implementation of `withdraw` functionality
    ///      - using `_executeSwap` because need to check if tokens are recognized by the system
    ///      - aToken is not approved before the call because lending pool doesn't need permission to burn it
    ///      - underlying is enabled after the call
    ///      - aToken is not disabled because operation doesn't spend the entire balance
    function _withdraw(address creditAccount, address asset, uint256 amount)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable,) =
            _executeSwapNoApprove(_aToken(asset), asset, _encodeWithdraw(creditAccount, asset, amount), false); // U:[AAVE2-5A]
    }

    /// @dev Internal implementation of `withdrawAll` functionality
    ///      - using `_executeSwap` because need to check if tokens are recognized by the system
    ///      - aToken is not approved before the call because lending pool doesn't need permission to burn it
    ///      - underlying is enabled after the call
    ///      - aToken is not disabled because operation spends the entire balance
    function _withdrawAll(address creditAccount, address asset)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address aToken = _aToken(asset);
        uint256 amount = IERC20(aToken).balanceOf(creditAccount); // U:[AAVE2-5B,6]
        if (amount <= 1) return (0, 0);
        unchecked {
            --amount; // U:[AAVE2-5B,6]
        }

        (tokensToEnable, tokensToDisable,) =
            _executeSwapNoApprove(aToken, asset, _encodeWithdraw(creditAccount, asset, amount), true); // U:[AAVE2-5B,6]
    }

    /// @dev Returns calldata for `ILendingPool.withdraw` call
    function _encodeWithdraw(address creditAccount, address asset, uint256 amount)
        internal
        pure
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(ILendingPool.withdraw, (asset, amount, creditAccount));
    }
}
