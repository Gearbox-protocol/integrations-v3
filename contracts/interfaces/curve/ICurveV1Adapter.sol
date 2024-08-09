// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

/// @title Curve V1 base adapter interface
interface ICurveV1Adapter is IAdapter {
    function token() external view returns (address);

    function lp_token() external view returns (address);

    function metapoolBase() external view returns (address);

    function nCoins() external view returns (uint256);

    function use256() external view returns (bool);

    function token0() external view returns (address);
    function token1() external view returns (address);
    function token2() external view returns (address);
    function token3() external view returns (address);

    function underlying0() external view returns (address);
    function underlying1() external view returns (address);
    function underlying2() external view returns (address);
    function underlying3() external view returns (address);

    // -------- //
    // EXCHANGE //
    // -------- //

    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external returns (bool useSafePrices);

    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (bool useSafePrices);

    function exchange_diff(uint256 i, uint256 j, uint256 leftoverAmount, uint256 rateMinRAY)
        external
        returns (bool useSafePrices);

    function exchange_underlying(uint256 i, uint256 j, uint256 dx, uint256 min_dy)
        external
        returns (bool useSafePrices);

    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy)
        external
        returns (bool useSafePrices);

    function exchange_diff_underlying(uint256 i, uint256 j, uint256 leftoverAmount, uint256 rateMinRAY)
        external
        returns (bool useSafePrices);

    // ------------- //
    // ADD LIQUIDITY //
    // ------------- //

    function add_liquidity_one_coin(uint256 amount, uint256 i, uint256 minAmount)
        external
        returns (bool useSafePrices);

    function add_diff_liquidity_one_coin(uint256 leftoverAmount, uint256 i, uint256 rateMinRAY)
        external
        returns (bool useSafePrices);

    function calc_add_one_coin(uint256 amount, uint256 i) external view returns (uint256);

    // ---------------- //
    // REMOVE LIQUIDITY //
    // ---------------- //

    function remove_liquidity_one_coin(uint256 amount, uint256 i, uint256 minAmount)
        external
        returns (bool useSafePrices);

    function remove_liquidity_one_coin(uint256 amount, int128 i, uint256 minAmount)
        external
        returns (bool useSafePrices);

    function remove_diff_liquidity_one_coin(uint256 leftoverAmount, uint256 i, uint256 rateMinRAY)
        external
        returns (bool useSafePrices);
}
