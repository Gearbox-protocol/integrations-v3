// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ZapperBase} from "./ZapperBase.sol";
import {IERC20Zapper} from "../interfaces/zappers/IERC20Zapper.sol";

/// @title ERC20 zapper base
/// @notice Base contract for zappers with ERC20 input token
abstract contract ERC20ZapperBase is ZapperBase, IERC20Zapper {
    /// @notice Performs deposit zap:
    ///         - receives `tokenInAmount` of `tokenIn` from `msg.sender` and converts it to `underlying`
    ///         - deposits `underlying` into `pool`
    ///         - converts `pool`'s shares to `tokenOutAmount` of `tokenOut` and sends it to `receiver`
    /// @dev Requires approval from `msg.sender` for `tokenIn` to this contract
    function deposit(uint256 tokenInAmount, address receiver) external returns (uint256 tokenOutAmount) {
        tokenOutAmount = _deposit(tokenInAmount, receiver, false, 0);
    }

    /// @notice Same as `deposit` but allows specifying the `referralCode` when depositing into the pool
    function depositWithReferral(uint256 tokenInAmount, address receiver, uint256 referralCode)
        external
        returns (uint256 tokenOutAmount)
    {
        tokenOutAmount = _deposit(tokenInAmount, receiver, true, referralCode);
    }
}
