// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IBalancerStablePool {
    function totalSupply() external view returns (uint256);

    function getActualSupply() external view returns (uint256);

    function getPoolId() external view returns (bytes32);

    function getRate() external view returns (uint256);
}
