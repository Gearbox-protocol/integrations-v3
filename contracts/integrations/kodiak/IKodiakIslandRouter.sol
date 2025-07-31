// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IKodiakIslandRouter {
    function addLiquidity(
        address island,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 minLPAmount,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function removeLiquidity(address island, uint256 lpAmount, uint256 amount0Min, uint256 amount1Min, address receiver)
        external
        returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);
}
