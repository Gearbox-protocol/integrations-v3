// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ILendingPool} from "./ILendingPool.sol";

interface IAToken is IERC20Metadata {
    /**
     * @dev Returns the address of the underlying asset of this aToken (E.g. WETH for aWETH)
     *
     */
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    /**
     * @dev Returns the address of the lending pool where this aToken is used
     *
     */
    function POOL() external view returns (ILendingPool);
}
