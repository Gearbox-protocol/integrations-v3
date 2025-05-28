// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IWETH} from "@gearbox-protocol/core-v3/contracts/interfaces/external/IWETH.sol";
import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {IFluidDex, ConstantViews} from "../../integrations/fluid/IFluidDex.sol";

/// @title FluidDexETHGateway
/// @notice Gateway contract to connect credit accounts with FluidDex pools that use native ETH
/// @dev Converts WETH to ETH and vice versa for operational purposes
contract FluidDexETHGateway is IVersion {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::FLUID_DEX_ETH";
    uint256 public constant override version = 3_10;

    /// @notice Special address used by Fluid to represent native ETH
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice The underlying FluidDex pool
    address public immutable pool;

    /// @notice WETH token address
    address public immutable weth;

    /// @notice The other token in the pair (not ETH)
    address public immutable otherToken;

    /// @notice Whether ETH is token0 in the pool (if false, it's token1)
    bool public immutable ethIsToken0;

    /// @notice Constructor
    /// @param _pool Address of the FluidDex pool
    /// @param _weth WETH token address
    constructor(address _pool, address _weth) {
        if (_pool == address(0) || _weth == address(0)) {
            revert ZeroAddressException();
        }

        pool = _pool;
        weth = _weth;

        // Get token addresses from the pool
        ConstantViews memory views = IFluidDex(_pool).constantsView();

        // Determine which token is ETH and which is the other token
        if (views.token0 == ETH) {
            ethIsToken0 = true;
            otherToken = views.token1;
        } else if (views.token1 == ETH) {
            ethIsToken0 = false;
            otherToken = views.token0;
        } else {
            revert("Pool does not contain ETH");
        }

        // Approve the other token to be spent by the pool
        IERC20(otherToken).forceApprove(_pool, type(uint256).max);
    }

    /// @notice Swaps tokens through the FluidDex pool
    /// @param swap0to1 Direction of swap (true for token0 to token1, false for token1 to token0)
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum amount of output token to receive
    /// @param to Recipient of the swap output
    /// @return amountOut Amount of tokens received
    function swapIn(bool swap0to1, uint256 amountIn, uint256 amountOutMin, address to)
        external
        returns (uint256 amountOut)
    {
        bool swapFromWeth = (ethIsToken0 && swap0to1) || (!ethIsToken0 && !swap0to1);

        if (swapFromWeth) {
            IERC20(weth).safeTransferFrom(msg.sender, address(this), amountIn);
            IWETH(weth).withdraw(amountIn);
            amountOut = IFluidDex(pool).swapIn{value: amountIn}(swap0to1, amountIn, amountOutMin, to);
        } else {
            uint256 balance = IERC20(otherToken).balanceOf(address(this));
            IERC20(otherToken).safeTransferFrom(msg.sender, address(this), amountIn);

            amountIn = IERC20(otherToken).balanceOf(address(this)) - balance;
            IFluidDex(pool).swapIn(swap0to1, amountIn, amountOutMin, address(this));

            IWETH(weth).deposit{value: address(this).balance}();
            amountOut = _transferAllTokensOf(weth, to);
        }

        return amountOut;
    }

    /// @notice Returns the constant views from the underlying pool
    /// @return views The constant views structure
    function constantsView() external view returns (ConstantViews memory) {
        ConstantViews memory views = IFluidDex(pool).constantsView();

        // Replace ETH with WETH in the returned structure
        if (ethIsToken0) {
            views.token0 = weth;
        } else {
            views.token1 = weth;
        }

        return views;
    }

    /// @dev Transfers the current balance of a token to sender (minus 1 for gas savings)
    /// @param _token Token to transfer
    function _transferAllTokensOf(address _token, address _to) internal returns (uint256) {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (balance > 1) {
            unchecked {
                IERC20(_token).safeTransfer(_to, balance - 1);
                return balance - 1;
            }
        }
        return 0;
    }

    /// @dev Allows the contract to receive ETH
    receive() external payable {}
}
