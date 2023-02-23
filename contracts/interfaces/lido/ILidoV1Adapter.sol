// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { IAdapter } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

interface ILidoV1AdapterEvents {
    event NewLimit(uint256 _limit);
}

interface ILidoV1AdapterExceptions {
    error LimitIsOverException();
}

interface ILidoV1Adapter is
    IAdapter,
    ILidoV1AdapterEvents,
    ILidoV1AdapterExceptions
{
    /// @dev Address of WETH
    function weth() external view returns (address);

    /// @dev Address of the Lido contract
    function stETH() external view returns (address);

    /// @dev Address of Gearbox treasury
    function treasury() external view returns (address);

    /// @dev The amount of WETH that can be deposited through this adapter
    function limit() external view returns (uint256);

    /// @dev Sends an order to stake ETH in Lido and receive stETH (sending WETH through the gateway)
    /// @param amount The amount of ETH to deposit in Lido
    /// @notice Since Gearbox only uses WETH as collateral, the amount has to be passed explicitly
    ///         unlike Lido. The referral address is always set to Gearbox treasury
    function submit(uint256 amount) external;

    /// @dev Sends an order to stake ETH in Lido and receive stETH (sending all available WETH through the gateway)
    function submitAll() external;

    /// @dev Set a new deposit limit
    /// @param _limit New value for the limit
    function setLimit(uint256 _limit) external;
}
