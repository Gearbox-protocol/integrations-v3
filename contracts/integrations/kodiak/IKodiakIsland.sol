// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IKodiakIsland {
    function getUnderlyingBalances() external view returns (uint256 balance0, uint256 balance1);

    function getMintAmounts(uint256 amount0, uint256 amount1)
        external
        view
        returns (uint256 amount0Min, uint256 amount1Min, uint256 lpAmount);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function pool() external view returns (address);
}

interface IKodiakPool {
    function fee() external view returns (uint24);
}
