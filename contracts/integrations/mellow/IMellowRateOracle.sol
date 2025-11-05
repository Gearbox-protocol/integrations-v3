// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IMellowRateOracle {
    function getRate() external view returns (uint256);
}
