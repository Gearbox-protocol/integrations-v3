// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IPool4626} from "@gearbox-protocol/core-v2/contracts/interfaces/IPool4626.sol";
import {IAToken} from "../../integrations/aave/IAToken.sol";
import {IWrappedAToken} from "./IWrappedAToken.sol";

/// @title waToken Gateway interface
/// @notice Allows LPs to add/remove aTokens to/from waToken liquidity pool
interface IWrappedATokenGateway {
    /// @notice Thrown when trying to create gateway to the contract that is not a registered pool
    error NotRegisteredPoolException();

    /// @notice waToken pool
    function pool() external view returns (IPool4626);

    /// @notice waToken address
    function waToken() external view returns (IWrappedAToken);

    /// @notice aToken address
    function aToken() external view returns (IAToken);

    /// @notice Deposit aTokens into waToken liquidity pool
    /// @dev Gateway must be approved to spend aTokens from `msg.sender` before the call
    /// @param assets Amount of aTokens to deposit to the pool
    /// @param receiver Account that should receive dTokens
    /// @param referralCode Referral code, for potential rewards
    /// @return shares Amount of dTokens minted to `receiver`
    function depositReferral(uint256 assets, address receiver, uint16 referralCode) external returns (uint256 shares);

    /// @notice Redeem aTokens from waToken liquidity pool
    /// @dev Gateway must be approved to spend dTokens from `owner` before the call
    /// @param shares Amount of dTokens to burn
    /// @param receiver Account that should receive aTokens
    /// @param owner Account to burn dTokens from
    /// @return assets Amount of aTokens sent to `receiver`
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}
