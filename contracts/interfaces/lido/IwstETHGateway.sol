// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IPool4626} from "@gearbox-protocol/core-v3/contracts/interfaces/IPool4626.sol";
import {IstETH} from "../../integrations/lido/IstETH.sol";
import {IwstETH} from "../../integrations/lido/IwstETH.sol";

/// @title wstETH Gateway interface
/// @notice Allows LPs to add/remove stETH to/from wstETH liquidity pool
interface IwstETHGateway {
    /// @notice Thrown when trying to create gateway to the contract that is not a registered pool
    error NotRegisteredPoolException();

    /// @notice wstETH pool
    function pool() external view returns (IPool4626);

    /// @notice wstETH address
    function wstETH() external view returns (IwstETH);

    /// @notice stETH address
    function stETH() external view returns (IstETH);

    /// @notice Deposit stETH into wstETH liquidity pool
    /// @dev Gateway must be approved to spend stETH from `msg.sender` before the call
    /// @param assets Amount of stETH to deposit to the pool
    /// @param receiver Account that should receive dTokens
    /// @param referralCode Referral code, for potential rewards
    /// @return shares Amount of dTokens minted to `receiver`
    function depositReferral(uint256 assets, address receiver, uint16 referralCode) external returns (uint256 shares);

    /// @notice Redeem stETH from wstETH liquidity pool
    /// @dev Gateway must be approved to spend dTokens from `owner` before the call
    /// @param shares Amount of dTokens to burn
    /// @param receiver Account that should receive stETH
    /// @param owner Account to burn dTokens from
    /// @return assets Amount of stETH sent to `receiver`
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}
