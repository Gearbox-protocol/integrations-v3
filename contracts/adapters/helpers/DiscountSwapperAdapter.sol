// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IDiscountSwapper} from "../../interfaces/discount/IDiscountSwapper.sol";
import {IDiscountSwapperAdapter} from "../../interfaces/discount/IDiscountSwapperAdapter.sol";

/// @title DiscountSwapper Adapter
/// @notice Implements logic for interacting with the DiscountSwapper contract
contract DiscountSwapperAdapter is AbstractAdapter, IDiscountSwapperAdapter {
    bytes32 public constant override contractType = "ADAPTER::DISCOUNT_SWAPPER";
    uint256 public constant override version = 3_10;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _targetContract DiscountSwapper contract address
    constructor(address _creditManager, address _targetContract) AbstractAdapter(_creditManager, _targetContract) {}

    /// @notice Swaps assetIn for assetOut based on the defined exchange rate
    /// @param assetIn The asset to send to the treasury
    /// @param assetOut The asset to receive from the treasury
    /// @param amountIn The amount of assetIn to swap
    function swap(address assetIn, address assetOut, uint256 amountIn)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _getMaskOrRevert(assetIn);
        _getMaskOrRevert(assetOut);

        _executeSwapSafeApprove(assetIn, abi.encodeCall(IDiscountSwapper.swap, (assetIn, assetOut, amountIn)));

        return false;
    }

    /// @notice Swaps all available assetIn for assetOut, except for a specified leftover amount
    /// @param assetIn The asset to send to the treasury
    /// @param assetOut The asset to receive from the treasury
    /// @param leftoverAmount The amount of assetIn to keep in the credit account
    function swapDiff(address assetIn, address assetOut, uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _getMaskOrRevert(assetIn);
        _getMaskOrRevert(assetOut);

        address creditAccount = _creditAccount();

        uint256 balance = IERC20(assetIn).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                _executeSwapSafeApprove(
                    assetIn, abi.encodeCall(IDiscountSwapper.swap, (assetIn, assetOut, balance - leftoverAmount))
                );
            }
        }

        return false;
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory) {
        return abi.encode(creditManager, targetContract);
    }
}
