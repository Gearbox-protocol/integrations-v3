// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {ZapperBase} from "./ZapperBase.sol";
import {IERC20ZapperDeposits} from "../interfaces/zappers/IERC20ZapperDeposits.sol";

/// @title ERC20 zapper base
/// @notice Base contract for zappers with ERC20 input token
abstract contract ERC20ZapperBase is ZapperBase, IERC20ZapperDeposits {
    /// @notice Performs deposit zap:
    ///         - receives `tokenInAmount` of `tokenIn` from `msg.sender` and converts it to `underlying`
    ///         - deposits `underlying` into `pool`
    ///         - converts `pool`'s shares to `tokenOutAmount` of `tokenOut` and sends it to `receiver`
    /// @dev Requires approval from `msg.sender` for `tokenIn` to this contract
    function deposit(uint256 tokenInAmount, address receiver) external returns (uint256 tokenOutAmount) {
        tokenOutAmount = _deposit(tokenInAmount, receiver, false, 0);
    }

    /// @notice Performs deposit zap using signed EIP-2612 permit message for zapper's input token:
    ///         - receives `tokenInAmount` of `tokenIn` from `msg.sender` and converts it to `underlying`
    ///         - deposits `underlying` into `pool`
    ///         - converts `pool`'s shares to `tokenOutAmount` of `tokenOut` and sends it to `receiver`
    /// @dev `v`, `r`, `s` must be a valid signature of the permit message from `msg.sender` for `tokenIn` to this contract
    function depositWithPermit(uint256 tokenInAmount, address receiver, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 tokenOutAmount)
    {
        _permit(tokenIn(), tokenInAmount, deadline, v, r, s);
        tokenOutAmount = _deposit(tokenInAmount, receiver, false, 0);
    }

    /// @notice Performs deposit zap using signed DAI-like permit message for zapper's input token:
    ///         - receives `tokenInAmount` of `tokenIn` from `msg.sender` and converts it to `underlying`
    ///         - deposits `underlying` into `pool`
    ///         - converts `pool`'s shares to `tokenOutAmount` of `tokenOut` and sends it to `receiver`
    /// @dev `v`, `r`, `s` must be a valid signature of the permit message from `msg.sender` for `tokenIn` to this contract
    function depositWithPermitAllowed(
        uint256 tokenInAmount,
        address receiver,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 tokenOutAmount) {
        _permitAllowed(tokenIn(), nonce, expiry, v, r, s);
        tokenOutAmount = _deposit(tokenInAmount, receiver, false, 0);
    }

    /// @notice Same as `deposit` but allows specifying the `referralCode` when depositing into the pool
    function depositWithReferral(uint256 tokenInAmount, address receiver, uint256 referralCode)
        external
        returns (uint256 tokenOutAmount)
    {
        tokenOutAmount = _deposit(tokenInAmount, receiver, true, referralCode);
    }

    /// @notice Same as `depositWithPermit` but allows specifying the `referralCode` when depositing into the pool
    function depositWithReferralAndPermit(
        uint256 tokenInAmount,
        address receiver,
        uint256 referralCode,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 tokenOutAmount) {
        _permit(tokenIn(), tokenInAmount, deadline, v, r, s);
        tokenOutAmount = _deposit(tokenInAmount, receiver, true, referralCode);
    }

    /// @notice Same as `depositWithPermitAllowed` but allows specifying the `referralCode` when depositing into the pool
    function depositWithReferralAndPermitAllowed(
        uint256 tokenInAmount,
        address receiver,
        uint256 referralCode,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 tokenOutAmount) {
        _permitAllowed(tokenIn(), nonce, expiry, v, r, s);
        tokenOutAmount = _deposit(tokenInAmount, receiver, true, referralCode);
    }
}
