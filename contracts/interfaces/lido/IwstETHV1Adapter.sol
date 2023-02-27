// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

interface IwstETHV1Adapter is IAdapter {
    /// @dev Address of the Lido contract
    function stETH() external view returns (address);

    /**
     * @notice Exchanges stETH to wstETH
     * @param _stETHAmount amount of stETH to wrap in exchange for wstETH
     * @dev Requirements:
     *  - `_stETHAmount` must be non-zero
     *  - msg.sender must approve at least `_stETHAmount` stETH to this
     *    contract.
     *  - msg.sender must have at least `_stETHAmount` of stETH.
     * User should first approve _stETHAmount to the WstETH contract
     */
    function wrap(uint256 _stETHAmount) external;

    /**
     * @notice Exchanges all stETH to wstETH
     * User should first approve _stETHAmount to the WstETH contract
     */
    function wrapAll() external;

    /**
     * @notice Exchanges wstETH to stETH
     * @param _wstETHAmount amount of wstETH to uwrap in exchange for stETH
     * @dev Requirements:
     *  - `_wstETHAmount` must be non-zero
     *  - msg.sender must have at least `_wstETHAmount` wstETH.
     */
    function unwrap(uint256 _wstETHAmount) external;

    /**
     * @notice Exchanges all wstETH to stETH
     */
    function unwrapAll() external;
}
