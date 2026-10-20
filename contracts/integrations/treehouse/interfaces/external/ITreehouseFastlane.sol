// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ITreehouseFastlane {
    function TASSET() external view returns (address);
    function UNDERLYING() external view returns (address);
    function redeemAndFinalize(uint96 _shares) external;
}
