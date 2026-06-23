// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IMidasDataFeed {
    function getDataInBase18() external view returns (uint256);
}
