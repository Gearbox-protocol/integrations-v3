// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

struct OracleReport {
    uint224 priceD18;
    uint32 timestamp;
    bool isSuspicious;
}

interface IMellowRateOracle {
    function getRate() external view returns (uint256);
    function reports(address asset) external view returns (uint256);
    function reportAt(address asset, uint256 index) external view returns (OracleReport memory);
    function acceptedAt(address asset, uint256 index) external view returns (uint32);
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
