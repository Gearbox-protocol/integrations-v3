// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IWstETH {
    function stEthPerToken() external view returns (uint256);
}
