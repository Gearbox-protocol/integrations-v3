// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IConvexRewardHook_L2 {
    function poolRewardLength(address pool) external view returns (uint256);
    function poolRewardList(address pool, uint256 index) external view returns (address);
}
