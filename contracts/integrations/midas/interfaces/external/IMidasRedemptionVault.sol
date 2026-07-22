// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

enum RedemptionStatus {
    PENDING,
    APPROVED,
    REJECTED
}

interface IMidasRedemptionVault {
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount) external;
    function redeemRequest(address tokenOut, uint256 amountMTokenIn) external returns (uint256);
    function currentRequestId() external view returns (uint256);
    function redeemRequests(uint256 requestId)
        external
        view
        returns (
            address sender,
            address tokenOut,
            RedemptionStatus status,
            uint256 amountMTokenIn,
            uint256 mTokenRate,
            uint256 tokenOutRate
        );
    function mToken() external view returns (address);

    function mTokenDataFeed() external view returns (address);
    function accessControl() external view returns (address);
}
