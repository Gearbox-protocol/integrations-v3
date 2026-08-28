// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IMellowSimpleLRTVault {
    function asset() external view returns (address);
    function withdrawalQueue() external view returns (address);
    function claim(address account, address recipient, uint256 maxAmount) external returns (uint256);
    function pendingAssetsOf(address account) external view returns (uint256);
    function claimableAssetsOf(address account) external view returns (uint256);
}

interface IMellowWithdrawalQueue {
    function balanceOf(address account) external view returns (uint256);
}
