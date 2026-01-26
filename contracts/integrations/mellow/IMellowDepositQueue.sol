// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IMellowDepositQueue {
    function vault() external view returns (address);
    function asset() external view returns (address);
    function claimableOf(address account) external view returns (uint256);
    function requestOf(address account) external view returns (uint256 timestamp, uint256 assets);
    function deposit(uint224 assets, address referral, bytes32[] calldata merkleProof) external;
    function cancelDepositRequest() external;
    function claim(address account) external;
}
