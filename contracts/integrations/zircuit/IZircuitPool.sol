// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IZircuitPool {
    function balance(address _token, address _account) external view returns (uint256);

    function depositFor(address _token, address _for, uint256 _amount) external;

    function withdraw(address _token, uint256 _amount) external;
}
