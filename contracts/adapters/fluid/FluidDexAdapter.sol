// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IFluidDex, ConstantViews} from "../../integrations/fluid/IFluidDex.sol";
import {IFluidDexAdapter} from "../../interfaces/fluid/IFluidDexAdapter.sol";

/// @title FluidDex Adapter
/// @notice Implements logic for interacting with the FluidDex exchange
contract FluidDexAdapter is AbstractAdapter, IFluidDexAdapter {
    bytes32 public constant override contractType = "ADAPTER::FLUID_DEX";
    uint256 public constant override version = 3_10;

    /// @notice Token0 in the FluidDex pair
    address public immutable override token0;

    /// @notice Token1 in the FluidDex pair
    address public immutable override token1;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _targetContract FluidDex contract address
    constructor(address _creditManager, address _targetContract) AbstractAdapter(_creditManager, _targetContract) {
        ConstantViews memory constantViews = IFluidDex(targetContract).constantsView();

        token0 = constantViews.token0;
        token1 = constantViews.token1;

        _getMaskOrRevert(token0);
        _getMaskOrRevert(token1);
    }

    /// @notice Swaps given amount of one token to another
    /// @param swap0to1 Direction of swap (true for token0 to token1, false for token1 to token0)
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum amount of output token to receive
    /// @dev The `to` parameter is ignored as it is always the Credit Account
    function swapIn(bool swap0to1, uint256 amountIn, uint256 amountOutMin, address)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        address creditAccount = _creditAccount();
        _swapIn(swap0to1, creditAccount, amountIn, amountOutMin);
        return true;
    }

    /// @notice Swaps the entire balance of one token to another, except the specified amount
    /// @param swap0to1 Direction of swap (true for token0 to token1, false for token1 to token0)
    /// @param leftoverAmount Amount of input token to keep on the account
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    function swapInDiff(bool swap0to1, uint256 leftoverAmount, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        address creditAccount = _creditAccount();
        address tokenIn = swap0to1 ? token0 : token1;

        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return false;

        unchecked {
            amount -= leftoverAmount;
        }

        _swapIn(swap0to1, creditAccount, amount, (amount * rateMinRAY) / RAY);
        return true;
    }

    /// @dev Internal implementation for `swapIn` and `swapInDiff`
    function _swapIn(bool swap0to1, address creditAccount, uint256 amountIn, uint256 amountOutMin) internal {
        address tokenIn = swap0to1 ? token0 : token1;
        _executeSwapSafeApprove(
            tokenIn, abi.encodeCall(IFluidDex.swapIn, (swap0to1, amountIn, amountOutMin, creditAccount))
        );
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, token0, token1);
    }
}
