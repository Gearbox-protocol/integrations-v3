// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IKelpLRTDepositPool {
    function depositETH(uint256 minRSETHAmountExpected, string calldata referralId) external payable;

    function depositAsset(
        address asset,
        uint256 depositAmount,
        uint256 minRSETHAmountExpected,
        string calldata referralId
    ) external;

    function getRsETHAmountToMint(address asset, uint256 amount) external view returns (uint256);

    function lrtConfig() external view returns (address);
}
