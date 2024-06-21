// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "../../interfaces/IAdapter.sol";

/// @title Lido V1 adapter interface
interface ILidoV1Adapter is IAdapter {
    function weth() external view returns (address);

    function stETH() external view returns (address);

    function wethTokenMask() external view returns (uint256);

    function stETHTokenMask() external view returns (uint256);

    function treasury() external view returns (address);

    function submit(uint256 amount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function submitDiff(uint256 leftoverAmount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
