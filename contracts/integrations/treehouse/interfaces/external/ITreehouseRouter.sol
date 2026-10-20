// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ITreehouseRouter {
    function TASSET() external view returns (address);
    function deposit(address token, uint256 amount) external;
}
