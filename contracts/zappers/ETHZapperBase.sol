// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ZapperBase} from "./ZapperBase.sol";
import {IETHZapperDeposits, ETH_ADDRESS} from "../interfaces/zappers/IETHZapperDeposits.sol";

/// @title ETH zapper base
/// @notice Base contract for zappers with ETH as input token
abstract contract ETHZapperBase is ZapperBase, IETHZapperDeposits {
    /// @inheritdoc ZapperBase
    /// @dev Returns special address denoting ETH
    function tokenIn() public pure override returns (address) {
        return ETH_ADDRESS;
    }

    /// @notice Performs deposit zap:
    ///         - receives ETH from `msg.sender` and converts it to `underlying`
    ///         - deposits `underlying` into `pool`
    ///         - converts `pool`'s shares to `tokenOutAmount` of `tokenOut` and sends it to `receiver`
    function deposit(address receiver) external payable returns (uint256 tokenOutAmount) {
        tokenOutAmount = _deposit(msg.value, receiver, false, 0);
    }

    /// @notice Same as `deposit` but allows specifying the `referralCode` when depositing into the pool
    function depositWithReferral(address receiver, uint256 referralCode)
        external
        payable
        returns (uint256 tokenOutAmount)
    {
        tokenOutAmount = _deposit(msg.value, receiver, true, referralCode);
    }
}
