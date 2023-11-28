// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IBalancerWeightedPool {
    function getRate() external view returns (uint256);

    function getNormalizedWeights() external view returns (uint256[] memory);

    function totalSupply() external view returns (uint256);

    function getActualSupply() external view returns (uint256);

    function getPoolId() external view returns (bytes32);
}
