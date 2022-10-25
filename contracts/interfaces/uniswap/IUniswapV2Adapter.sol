// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IAdapter } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import { IUniswapV2Router02 } from "../../integrations/uniswap/IUniswapV2Router02.sol";

interface IUniswapV2Adapter is IAdapter, IUniswapV2Router02 {
    /// @dev Sends an order to swap the entire token balance to another token using a Uniswap-compatible protocol
    /// @param rateMinRAY The minimal exchange rate between the input and the output tokens.
    //// @param path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of
    ///        addresses must exist and have liquidity.
    /// @param deadline Unix timestamp after which the transaction will revert.
    /// @return amounts amountsOut, in the order of swaps in the path
    function swapAllTokensForTokens(
        uint256 rateMinRAY,
        address[] calldata path,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
