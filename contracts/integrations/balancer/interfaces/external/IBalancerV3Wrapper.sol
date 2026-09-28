// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IBalancerV3Wrapper {
    function balancerPoolToken() external view returns (address);
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
}
