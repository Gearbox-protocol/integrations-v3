// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

struct Ratios {
    uint256 priceRatio;
    uint256 depositRatio;
    bool is0to1;
}

interface IKodiakIslandHelper {
    function addLiquidityImbalanced(
        address island,
        uint256 amount0,
        uint256 amount1,
        uint256 minLPAmount,
        address receiver
    ) external returns (uint256 lpAmount);

    function addLiquidityImbalancedAssisted(
        address island,
        uint256 amount0,
        uint256 amount1,
        uint256 minLPAmount,
        address receiver,
        Ratios memory ratios
    ) external returns (uint256 lpAmount);

    function estimateAddLiquidityImbalanced(address island, uint256 amount0, uint256 amount1)
        external
        returns (uint256 lpAmount, Ratios memory ratios);

    function removeLiquidityImbalanced(
        address island,
        uint256 lpAmount,
        uint256 token0proportion,
        uint256[2] memory minAmounts,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1);

    function estimateRemoveLiquidityImbalanced(address island, uint256 lpAmount, uint256 token0proportion)
        external
        returns (uint256 amount0, uint256 amount1);
}
