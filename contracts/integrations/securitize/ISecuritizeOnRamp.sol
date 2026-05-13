// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ISecuritizeOnRamp {
    function swap(uint256 _liquidityAmount, uint256 _minOutAmount) external;

    function calculateDsTokenAmount(uint256 _liquidityAmount)
        external
        view
        returns (uint256 dsTokenAmount, uint256 rate, uint256 fee);

    function dsToken() external view returns (address);

    function liquidityToken() external view returns (address);

    function navProvider() external view returns (address);
}
