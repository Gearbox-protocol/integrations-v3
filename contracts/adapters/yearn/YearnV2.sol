// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IYVault} from "../../integrations/yearn/IYVault.sol";
import {IYearnV2Adapter} from "../../interfaces/yearn/IYearnV2Adapter.sol";

/// @title Yearn V2 Vault adapter
/// @notice Implements logic allowing CAs to deposit into Yearn vaults
contract YearnV2Adapter is AbstractAdapter, IYearnV2Adapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.YEARN_V2;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice Vault's underlying token address
    address public immutable override token;

    /// @notice Collateral token mask of underlying token in the credit manager
    uint256 public immutable override tokenMask;

    /// @notice Collateral token mask of yToken in the credit manager
    uint256 public immutable override yTokenMask;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault Yearn vault address
    constructor(address _creditManager, address _vault)
        AbstractAdapter(_creditManager, _vault) // U:[YFI2-1]
    {
        token = IYVault(targetContract).token(); // U:[YFI2-1]
        tokenMask = _getMaskOrRevert(token); // U:[YFI2-1]
        yTokenMask = _getMaskOrRevert(_vault); // U:[YFI2-1]
    }

    // -------- //
    // DEPOSITS //
    // -------- //

    /// @notice Deposit the entire balance of underlying tokens into the vault, except the specified amount
    function depositDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[YFI2-3]

        uint256 balance = IERC20(token).balanceOf(creditAccount); // U:[YFI2-3]
        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _deposit(balance - leftoverAmount, leftoverAmount <= 1); // U:[YFI2-3]
            }
        }
    }

    /// @notice Deposit given amount of underlying tokens into the vault
    /// @param amount Amount of underlying tokens to deposit
    function deposit(uint256 amount)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _deposit(amount, false); // U:[YFI2-4]
    }

    /// @notice Deposit given amount of underlying tokens into the vault
    /// @param amount Amount of underlying tokens to deposit
    /// @dev Second param (`recipient`) is ignored because it can only be the credit account
    function deposit(uint256 amount, address)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _deposit(amount, false); // U:[YFI2-5]
    }

    /// @dev Internal implementation of `deposit` functions
    ///      - underlying is approved before the call because vault needs permission to transfer it
    ///      - yToken is enabled after the call
    ///      - underlying is only disabled when depositing the entire balance
    function _deposit(uint256 amount, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(token, type(uint256).max); // U:[YFI2-3,4,5]
        _execute(abi.encodeWithSignature("deposit(uint256)", amount)); // U:[YFI2-3,4,5]
        _approveToken(token, 1); // U:[YFI2-3,4,5]
        (tokensToEnable, tokensToDisable) = (yTokenMask, disableTokenIn ? tokenMask : 0);
    }

    // ----------- //
    // WITHDRAWALS //
    // ----------- //

    /// @notice Withdraw the entire balance of underlying from the vault, except the specified amount
    function withdrawDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[YFI2-6]

        uint256 balance = IERC20(targetContract).balanceOf(creditAccount); // U:[YFI2-6]

        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _withdraw(balance - leftoverAmount, leftoverAmount <= 1); // U:[YFI2-6]
            }
        }
    }

    /// @notice Burn given amount of yTokens to withdraw corresponding amount of underlying from the vault
    /// @param maxShares Amout of yTokens to burn
    function withdraw(uint256 maxShares)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdraw(maxShares, false); // U:[YFI2-7]
    }

    /// @notice Burn given amount of yTokens to withdraw corresponding amount of underlying from the vault
    /// @param maxShares Amout of yTokens to burn
    /// @dev Second param (`recipient`) is ignored because it can only be the credit account
    function withdraw(uint256 maxShares, address)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _withdraw(maxShares, false); // U:[YFI2-8]
    }

    /// @notice Burn given amount of yTokens to withdraw corresponding amount of underlying from the vault
    /// @param maxShares Amout of yTokens to burn
    /// @param maxLoss Maximal slippage on withdrawal in basis points
    /// @dev Second param (`recipient`) is ignored because it can only be the credit account
    function withdraw(uint256 maxShares, address, uint256 maxLoss)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[YFI2-9]
        (tokensToEnable, tokensToDisable) = _withdraw(maxShares, creditAccount, maxLoss); // U:[YFI2-9]
    }

    /// @dev Internal implementation of `withdraw` functions
    ///      - yToken is not approved because vault doesn't need permission to burn it
    ///      - underlying is enabled after the call
    ///      - yToken is only disabled when withdrawing the entire balance
    function _withdraw(uint256 maxShares, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(abi.encodeWithSignature("withdraw(uint256)", maxShares)); // U:[YFI2-6,7,8]
        (tokensToEnable, tokensToDisable) = (tokenMask, disableTokenIn ? yTokenMask : 0);
    }

    /// @dev Internal implementation of `withdraw` function with `maxLoss` argument
    ///      - yToken is not approved because vault doesn't need permission to burn it
    ///      - underlying is enabled after the call
    ///      - yToken is not disabled after the call
    function _withdraw(uint256 maxShares, address creditAccount, uint256 maxLoss)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(abi.encodeWithSignature("withdraw(uint256,address,uint256)", maxShares, creditAccount, maxLoss)); // U:[YFI2-9]
        (tokensToEnable, tokensToDisable) = (tokenMask, 0);
    }
}
