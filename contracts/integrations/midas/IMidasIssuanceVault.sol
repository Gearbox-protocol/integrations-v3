// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IMidasIssuanceVault {
    function depositInstant(address tokenIn, uint256 amountToken, uint256 minReceiveAmount, bytes32 referrerId)
        external;
    function mToken() external view returns (address);
}
