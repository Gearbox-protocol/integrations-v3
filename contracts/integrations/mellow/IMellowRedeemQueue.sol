// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

struct Request {
    uint256 timestamp;
    uint256 shares;
    bool isClaimable;
    uint256 assets;
}

interface IMellowRedeemQueue {
    function vault() external view returns (address);
    function asset() external view returns (address);
    function requestsOf(address account, uint256 offset, uint256 limit)
        external
        view
        returns (Request[] memory requests);
    function redeem(uint256 shares) external;
    function claim(address receiver, uint32[] calldata timestamps) external returns (uint256 assets);
}
