// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IMellowRateOracle {
    function getRate() external view returns (uint256);
    function securityParams()
        external
        view
        returns (
            uint224 maxAbsoluteDeviation,
            uint224 suspiciousAbsoluteDeviation,
            uint64 maxRelativeDeviationD18,
            uint64 suspiciousRelativeDeviationD18,
            uint32 timeout,
            uint32 depositInterval,
            uint32 redeemInterval
        );
}
