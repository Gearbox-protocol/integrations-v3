// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import {AbstractAdapter} from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";

import {IYVault} from "../../integrations/yearn/IYVault.sol";
import {IYearnV2Adapter} from "../../interfaces/yearn/IYearnV2Adapter.sol";

/// @title Yearn V2 Vault adapter
/// @notice Implements logic allowing CAs to deposit into Yearn vaults
contract YearnV2Adapter is AbstractAdapter, IYearnV2Adapter {
    /// @notice Vault's underlying token address
    address public immutable override token;

    /// @notice Collateral token mask of underlying token in the credit manager
    uint256 public immutable override tokenMask;

    /// @notice Collateral token mask of eToken in the credit manager
    uint256 public immutable override yTokenMask;

    AdapterType public constant override _gearboxAdapterType = AdapterType.YEARN_V2;
    uint16 public constant override _gearboxAdapterVersion = 3;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault Yearn vault address
    constructor(address _creditManager, address _vault) AbstractAdapter(_creditManager, _vault) {
        token = IYVault(targetContract).token(); // F: [AYV2-1]

        tokenMask = creditManager.tokenMasksMap(token); // F: [AYV2-1]
        if (tokenMask == 0) {
            revert TokenIsNotInAllowedList(token); // F: [AYV2-2]
        }

        yTokenMask = creditManager.tokenMasksMap(_vault); // F: [AYV2-1]
        if (yTokenMask == 0) {
            revert TokenIsNotInAllowedList(_vault); // F: [AYV2-2]
        }
    }

    /// -------- ///
    /// DEPOSITS ///
    /// -------- ///

    /// @notice Deposit the entire balance of underlying tokens into the vault, disables underlying
    function deposit() external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F: [AYV2-3]

        uint256 balance = IERC20(token).balanceOf(creditAccount);

        if (balance > 1) {
            unchecked {
                _deposit(balance - 1, true); // F: [AYV2-4]
            }
        }
    }

    /// @notice Deposit given amount of underlying tokens into the vault
    /// @param amount Amount of underlying tokens to deposit
    function deposit(uint256 amount) external override creditFacadeOnly {
        _deposit(amount, false); // F: [AYV2-5]
    }

    /// @notice Deposit given amount of underlying tokens into the vault
    /// @param amount Amount of underlying tokens to deposit
    /// @dev Second param (`recipient`) is ignored because it can only be the credit account
    function deposit(uint256 amount, address) external override creditFacadeOnly {
        _deposit(amount, false); // F: [AYV2-6]
    }

    /// @dev Internal implementation of `deposit` functions
    ///      - underlying is approved before the call because vault needs permission to transfer it
    ///      - yToken is enabled after the call
    ///      - underlying is only disabled when depositing the entire balance
    function _deposit(uint256 amount, bool disableTokenIn) internal {
        _approveToken(token, type(uint256).max);
        _execute(abi.encodeWithSignature("deposit(uint256)", amount));
        _approveToken(token, 1);
        _changeEnabledTokens(yTokenMask, disableTokenIn ? tokenMask : 0);
    }

    /// ----------- ///
    /// WITHDRAWALS ///
    /// ----------- ///

    /// @notice Withdraw the entire balance of underlying from the vault, disables yToken
    function withdraw() external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F: [AYV2-3]

        uint256 balance = IERC20(targetContract).balanceOf(creditAccount);

        if (balance > 1) {
            unchecked {
                _withdraw(balance - 1, true); // F: [AYV2-7]
            }
        }
    }

    /// @notice Burn given amount of yTokens to withdraw corresponding amount of underlying from the vault
    /// @param maxShares Amout of yTokens to burn
    function withdraw(uint256 maxShares) external override creditFacadeOnly {
        _withdraw(maxShares, false); // F: [AYV2-8]
    }

    /// @notice Burn given amount of yTokens to withdraw corresponding amount of underlying from the vault
    /// @param maxShares Amout of yTokens to burn
    /// @dev Second param (`recipient`) is ignored because it can only be the credit account
    function withdraw(uint256 maxShares, address) external override creditFacadeOnly {
        _withdraw(maxShares, false); // F: [AYV2-9]
    }

    /// @notice Burn given amount of yTokens to withdraw corresponding amount of underlying from the vault
    /// @param maxShares Amout of yTokens to burn
    /// @param maxLoss Maximal slippage on withdrawal in basis points
    /// @dev Second param (`recipient`) is ignored because it can only be the credit account
    function withdraw(uint256 maxShares, address, uint256 maxLoss) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F: [AYV2-3]
        _withdraw(maxShares, creditAccount, maxLoss); // F: [AYV2-10,11]
    }

    /// @dev Internal implementation of `withdraw` functions
    ///      - yToken is not approved because vault doesn't need permission to burn it
    ///      - underlying is enabled after the call
    ///      - yToken is only disabled when withdrawing the entire balance
    function _withdraw(uint256 maxShares, bool disableTokenIn) internal {
        _execute(abi.encodeWithSignature("withdraw(uint256)", maxShares));
        _changeEnabledTokens(tokenMask, disableTokenIn ? yTokenMask : 0);
    }

    /// @dev Internal implementation of `withdraw` function with `maxLoss` argument
    ///      - yToken is not approved because vault doesn't need permission to burn it
    ///      - underlying is enabled after the call
    ///      - yToken is not disabled after the call
    function _withdraw(uint256 maxShares, address creditAccount, uint256 maxLoss) internal {
        _execute(abi.encodeWithSignature("withdraw(uint256,address,uint256)", maxShares, creditAccount, maxLoss));
        _changeEnabledTokens(tokenMask, 0);
    }
}
