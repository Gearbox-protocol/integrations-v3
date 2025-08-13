// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

/// @title Lido withdrawal queue gateway interface
interface ILidoWithdrawalQueueGateway is IVersion {
    function weth() external view returns (address);

    function steth() external view returns (address);

    function wsteth() external view returns (address);

    function withdrawalQueue() external view returns (address);

    function getPendingWETH(address account) external view returns (uint256);

    function getClaimableWETH(address account) external view returns (uint256);

    function requestWithdrawals(uint256[] calldata amounts) external returns (uint256[] memory requestIds);

    function requestWithdrawalsWstETH(uint256[] calldata amounts) external returns (uint256[] memory requestIds);

    function claimWithdrawals(uint256 amount) external;
}
