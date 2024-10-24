// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

/// @title DAI/USDS Adapter Interface
/// @notice Interface for the DAI/USDS adapter contract
interface IDaiUsdsAdapter is IAdapter {
    /// @notice DAI token address
    function dai() external view returns (address);

    /// @notice USDS token address
    function usds() external view returns (address);

    /// @notice Collateral token mask of DAI in the credit manager
    function daiMask() external view returns (uint256);

    /// @notice Collateral token mask of USDS in the credit manager
    function usdsMask() external view returns (uint256);

    /// @notice Swaps given amount of DAI to USDS
    /// @param usr Recipient address (ignored, always Credit Account)
    /// @param wad Amount of DAI to swap
    function daiToUsds(address usr, uint256 wad) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Swaps the entire balance of DAI to USDS, except the specified amount
    /// @param leftoverAmount Amount of DAI to keep on the account
    function daiToUsdsDiff(uint256 leftoverAmount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Swaps given amount of USDS to DAI
    /// @param usr Recipient address (ignored, always Credit Account)
    /// @param wad Amount of USDS to swap
    function usdsToDai(address usr, uint256 wad) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    /// @notice Swaps the entire balance of USDS to DAI, except the specified amount
    /// @param leftoverAmount Amount of USDS to keep on the account
    function usdsToDaiDiff(uint256 leftoverAmount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
