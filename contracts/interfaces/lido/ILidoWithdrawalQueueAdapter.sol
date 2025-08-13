// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IPhantomTokenAdapter} from "../IPhantomTokenAdapter.sol";

/// @title Lido withdrawal queue adapter interface
interface ILidoWithdrawalQueueAdapter is IPhantomTokenAdapter {
    function stETH() external view returns (address);

    function wstETH() external view returns (address);

    function weth() external view returns (address);

    function lidoWithdrawalPhantomToken() external view returns (address);

    function requestWithdrawals(uint256[] calldata amounts) external returns (bool);

    function requestWithdrawalsWstETH(uint256[] calldata amounts) external returns (bool);

    function claimWithdrawals(uint256 amount) external returns (bool);
}
