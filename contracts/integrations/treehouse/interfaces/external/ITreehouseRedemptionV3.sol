// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

struct RedemptionInfo {
    uint64 startTime;
    uint96 shares;
    uint128 assets;
    uint128 baseRate;
}

uint32 constant FEE_PRECISION = 1e4;

interface ITreehouseRedemptionV3 {
    function TASSET() external view returns (address);
    function VAULT() external view returns (address);
    function redemptionFee() external view returns (uint32);
    function treasuryFee() external view returns (uint32);
    function waitingPeriod() external view returns (uint32);
    function redeem(uint96 _shares) external;
    function finalizeRedeem(uint256 _redemptionIndex) external;
    function getRedeemInfo(address _user, uint256 _redemptionIndex) external view returns (RedemptionInfo memory);
    function getRedeemLength(address _user) external view returns (uint256);
}
