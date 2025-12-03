// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IKelpLRTWithdrawalManager {
    function initiateWithdrawal(address asset, uint256 rsETHUnstaked, string calldata referralId) external;

    function completeWithdrawal(address asset, string calldata referralId) external;

    function getExpectedAssetAmount(address asset, uint256 amount)
        external
        view
        returns (uint256 underlyingToReceive);

    function getUserWithdrawalRequest(address asset, address user, uint256 userIndex)
        external
        view
        returns (uint256 rsETHAmount, uint256 expectedAssetAmount, uint256 withdrawalStartBlock, uint256 userNonce);

    function nextLockedNonce(address asset) external view returns (uint256);

    function userAssociatedNonces(address asset, address user) external view returns (uint128 start, uint128 end);
}
