// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ISecuritizeOnRamp {
    function swap(uint256 _liquidityAmount, uint256 _minOutAmount) external returns (uint256);

    function calculateDsTokenAmount(uint256 _liquidityAmount) external view returns (uint256);

    function dsToken() external view returns (address);

    function stableCoinToken() external view returns (address);
}
