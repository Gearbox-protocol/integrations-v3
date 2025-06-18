// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IUpTBTCVault {
    function requestRedeem(uint256 shares, address receiverAddr, address holderAddr) external;

    function claim(uint256 year, uint256 month, uint256 day, address receiverAddr) external;

    function getWithdrawalEpoch()
        external
        view
        returns (uint256 year, uint256 month, uint256 day, uint256 claimableEpoch);

    function getClaimableAmountByReceiver(uint256 year, uint256 month, uint256 day, address receiverAddr)
        external
        view
        returns (uint256);
}
