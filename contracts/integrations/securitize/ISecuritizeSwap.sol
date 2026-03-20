// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ISecuritizeSwap {
    function buy(uint256 _dsTokenAmount, uint256 _maxStableCoinAmount) external returns (uint256);

    function calculateDsTokenAmount(uint256 _stableCoinAmount) external view returns (uint256);

    function dsToken() external view returns (address);

    function stableCoinToken() external view returns (address);
}
