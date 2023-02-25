// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AdapterType } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import { AbstractAdapter } from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";

import { IYVault } from "../../integrations/yearn/IYVault.sol";
import { IYearnV2Adapter } from "../../interfaces/yearn/IYearnV2Adapter.sol";

/// @title Yearn adapter
/// @dev Implements logic for interacting with a Yearn vault
contract YearnV2Adapter is AbstractAdapter, IYearnV2Adapter {
    /// @dev Address of the token that is deposited into the vault
    address public immutable override token;

    AdapterType public constant _gearboxAdapterType = AdapterType.YEARN_V2;
    uint16 public constant _gearboxAdapterVersion = 3;

    /// @dev Constructor
    /// @param _creditManager Address Credit manager
    /// @param _yVault Address of YEARN vault contract
    constructor(
        address _creditManager,
        address _yVault
    ) AbstractAdapter(_creditManager, _yVault) {
        // Check that we have token connected with this yearn pool
        token = IYVault(targetContract).token(); // F:[AYV2-1]

        if (creditManager.tokenMasksMap(token) == 0)
            revert TokenIsNotInAllowedList(token); // F:[AYV2-2]

        if (creditManager.tokenMasksMap(_yVault) == 0)
            revert TokenIsNotInAllowedList(_yVault); // F:[AYV2-2]
    }

    /// @dev Sends an order to deposit the entire token balance to the vault
    /// The input token does need to be disabled, because this spends the entire balance
    function deposit() external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AYV2-3]

        uint256 balance = IERC20(token).balanceOf(creditAccount);

        if (balance > 1) {
            unchecked {
                _deposit(creditAccount, balance - 1, true);
            } // F:[AYV2-4]
        }
    }

    /// @dev Sends an order to deposit tokens into the vault
    /// @param amount The amount to be deposited
    /// The input token does not need to be disabled, because this does not spend the entire
    /// balance, generally
    function deposit(uint256 amount) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AYV2-3]
        _deposit(creditAccount, amount, false); // F:[AYV2-5]
    }

    /// @dev Sends an order to deposit tokens into the vault
    /// @param amount The amount to be deposited
    /// @notice `recipient` is ignored since a CA cannot send tokens to another account
    /// The input token does not need to be disabled, because this does not spend the entire
    /// balance, generally
    function deposit(
        uint256 amount,
        address
    ) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AYV2-3]
        _deposit(creditAccount, amount, false); // F:[AYV2-6]
    }

    /// @dev Internal implementation for `deposit` functions
    /// - Makes a safe allowance fast check call to `deposit(uint256)` (since the address is always ignored)
    /// @param creditAccount The Credit Account from which the operation is performed
    /// @param amount The amount of token to deposit
    /// @notice Fast check parameters:
    /// Input token: Vault underlying token
    /// Output token: Yearn vault share
    /// Input token is allowed, since the target does a transferFrom for the deposited asset
    function _deposit(
        address creditAccount,
        uint256 amount,
        bool disableTokenIn
    ) internal {
        _executeSwapSafeApprove(
            creditAccount,
            token,
            targetContract,
            abi.encodeWithSignature("deposit(uint256)", amount),
            disableTokenIn
        ); // F:[AYV2-4,5,6]
    }

    /// @dev Sends an order to withdraw all available shares from the vault
    /// The input token does need to be disabled, because this spends the entire balance
    function withdraw() external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AYV2-3]

        uint256 balance = IERC20(targetContract).balanceOf(creditAccount);

        if (balance > 1) {
            unchecked {
                _withdraw(creditAccount, balance - 1, true);
            } // F:[AYV2-7]
        }
    }

    /// @dev Sends an order to withdraw shares from the vault
    /// @param maxShares Number of shares to withdraw
    /// The input token does not need to be disabled, because this does not spend the entire
    /// balance, generally
    function withdraw(uint256 maxShares) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AYV2-3]
        _withdraw(creditAccount, maxShares, false); // F:[AYV2-8]
    }

    /// @dev Sends an order to withdraw shares from the vault
    /// @param maxShares Number of shares to withdraw
    /// @notice `recipient` is ignored since a CA cannot send tokens to another account
    /// The input token does not need to be disabled, because this does not spend the entire
    /// balance, generally
    function withdraw(
        uint256 maxShares,
        address
    ) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AYV2-3]
        _withdraw(creditAccount, maxShares, false); // F:[AYV2-9]
    }

    /// @dev Sends an order to withdraw shares from the vault, with a slippage limit
    /// @param maxShares Number of shares to withdraw
    ///  @param maxLoss Maximal slippage on withdrawal in basis points
    /// The input token does not need to be disabled, because this does not spend the entire
    /// balance, generally
    function withdraw(
        uint256 maxShares,
        address,
        uint256 maxLoss
    ) public override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AYV2-3]
        _withdrawMaxLoss(creditAccount, maxShares, maxLoss); // F:[AYV2-10,11]
    }

    /// @dev Internal implementation for `withdraw` functions
    /// - Makes a safe allowance fast check call to `withdraw(uint256)` in target
    /// @param creditAccount The credit account that will withdraw tokens
    /// @param maxShares Number of shares to withdraw
    /// @notice Fast check parameters:
    /// Input token: Yearn vault share
    /// Output token: Vault underlying token
    /// Input token does not have to be allowed, since the vault burns the shares directly
    function _withdraw(
        address creditAccount,
        uint256 maxShares,
        bool disableTokenIn
    ) internal {
        _executeSwapNoApprove(
            creditAccount,
            targetContract,
            token,
            abi.encodeWithSignature("withdraw(uint256)", maxShares),
            disableTokenIn
        ); // F:[AYV2-7,8,9]
    }

    /// @dev Internal implementation for the `withdraw` function with maxLoss
    /// - Makes a safe allowance fast check call to `withdraw(uint256,address,uint256)` in target
    /// @param creditAccount The credit account that will withdraw tokens
    /// @param maxShares Number of shares to withdraw
    /// @param maxLoss Maximal slippage on withdrawal, in basis points
    /// @notice Fast check parameters:
    /// Input token: Yearn vault share
    /// Output token: Vault underlying token
    /// Input token does not have to be allowed, since the vault burns the shares directly
    function _withdrawMaxLoss(
        address creditAccount,
        uint256 maxShares,
        uint256 maxLoss
    ) internal {
        _executeSwapNoApprove(
            creditAccount,
            targetContract,
            token,
            abi.encodeWithSignature(
                "withdraw(uint256,address,uint256)",
                maxShares,
                creditAccount,
                maxLoss
            ),
            false
        ); // F:[AYV2-10,11]
    }
}
