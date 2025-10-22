// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IMidasRedemptionVault {
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount) external;
    function redeemRequest(address tokenOut, uint256 amountMTokenIn) external;
    function currentRequestId() external view returns (uint256);
    function redeemRequests(uint256 requestId)
        external
        view
        returns (
            address sender,
            address tokenOut,
            uint8 status,
            uint256 amountMTokenIn,
            uint256 mTokenRate,
            uint256 tokenOutRate
        );
    function mToken() external view returns (address);
}
