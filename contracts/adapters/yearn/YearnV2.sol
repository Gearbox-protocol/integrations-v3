// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IYVault} from "../../integrations/yearn/IYVault.sol";
import {IYearnV2Adapter} from "../../interfaces/yearn/IYearnV2Adapter.sol";

/// @title Yearn V2 Vault adapter
/// @notice Implements logic allowing CAs to deposit into Yearn vaults
contract YearnV2Adapter is AbstractAdapter, IYearnV2Adapter {
    bytes32 public constant override contractType = "AD_YEARN_V2";
    uint256 public constant override version = 3_10;

    /// @notice Vault's underlying token address
    address public immutable override token;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault Yearn vault address
    constructor(address _creditManager, address _vault)
        AbstractAdapter(_creditManager, _vault) // U:[YFI2-1]
    {
        token = IYVault(targetContract).token(); // U:[YFI2-1]

        // We verify that the vault asset and shares are valid collaterals
        // in the system before deployment
        _getMaskOrRevert(token); // U:[YFI2-1]
        _getMaskOrRevert(_vault); // U:[YFI2-1]
    }

    // -------- //
    // DEPOSITS //
    // -------- //

    /// @notice Deposit the entire balance of underlying tokens into the vault, except the specified amount
    function depositDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[YFI2-3]

        uint256 balance = IERC20(token).balanceOf(creditAccount); // U:[YFI2-3]
        if (balance > leftoverAmount) {
            unchecked {
                _deposit(balance - leftoverAmount); // U:[YFI2-3]
            }
        }

        return false;
    }

    /// @notice Deposit given amount of underlying tokens into the vault
    /// @param amount Amount of underlying tokens to deposit
    function deposit(uint256 amount)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (bool)
    {
        _deposit(amount); // U:[YFI2-4]
        return false;
    }

    /// @notice Deposit given amount of underlying tokens into the vault
    /// @param amount Amount of underlying tokens to deposit
    /// @dev Second param (`recipient`) is ignored because it can only be the credit account
    function deposit(uint256 amount, address)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (bool)
    {
        _deposit(amount); // U:[YFI2-5]
        return false;
    }

    /// @dev Internal implementation of `deposit` functions
    function _deposit(uint256 amount) internal {
        _executeSwapSafeApprove(token, abi.encodeWithSignature("deposit(uint256)", amount)); // U:[YFI2-3,4,5]
    }

    // ----------- //
    // WITHDRAWALS //
    // ----------- //

    /// @notice Withdraw the entire balance of underlying from the vault, except the specified amount
    function withdrawDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[YFI2-6]

        uint256 balance = IERC20(targetContract).balanceOf(creditAccount); // U:[YFI2-6]

        if (balance > leftoverAmount) {
            unchecked {
                _withdraw(balance - leftoverAmount); // U:[YFI2-6]
            }
        }
        return false;
    }

    /// @notice Burn given amount of yTokens to withdraw corresponding amount of underlying from the vault
    /// @param maxShares Amout of yTokens to burn
    function withdraw(uint256 maxShares)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (bool)
    {
        _withdraw(maxShares); // U:[YFI2-7]
        return false;
    }

    /// @notice Burn given amount of yTokens to withdraw corresponding amount of underlying from the vault
    /// @param maxShares Amout of yTokens to burn
    /// @dev Second param (`recipient`) is ignored because it can only be the credit account
    function withdraw(uint256 maxShares, address)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (bool)
    {
        _withdraw(maxShares); // U:[YFI2-8]
        return false;
    }

    /// @notice Burn given amount of yTokens to withdraw corresponding amount of underlying from the vault
    /// @param maxShares Amout of yTokens to burn
    /// @param maxLoss Maximal slippage on withdrawal in basis points
    /// @dev Second param (`recipient`) is ignored because it can only be the credit account
    function withdraw(uint256 maxShares, address, uint256 maxLoss)
        external
        override
        creditFacadeOnly // U:[YFI2-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[YFI2-9]
        _execute(abi.encodeWithSignature("withdraw(uint256,address,uint256)", maxShares, creditAccount, maxLoss)); // U:[YFI2-9]
        return false;
    }

    /// @dev Internal implementation of `withdraw` functions
    function _withdraw(uint256 maxShares) internal {
        _execute(abi.encodeWithSignature("withdraw(uint256)", maxShares)); // U:[YFI2-6,7,8]
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, token);
    }
}
