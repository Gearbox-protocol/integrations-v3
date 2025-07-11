// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {IKodiakIslandHelper, Ratios} from "../../interfaces/kodiak/IKodiakIslandHelper.sol";
import {IKodiakIsland, IKodiakPool} from "../../integrations/kodiak/IKodiakIsland.sol";
import {IKodiakIslandRouter} from "../../integrations/kodiak/IKodiakIslandRouter.sol";
import {IKodiakQuoter, QuoteExactInputSingleParams} from "../../integrations/kodiak/IKodiakQuoter.sol";
import {IKodiakSwapRouter, ExactInputSingleParams} from "../../integrations/kodiak/IKodiakSwapRouter.sol";

contract KodiakIslandHelper is IKodiakIslandHelper {
    using SafeERC20 for IERC20;
    using Math for uint256;

    bytes32 public immutable contractType = "HELPER::KODIAK_ISLAND";
    uint256 public immutable version = 3_10;

    /// @notice The Kodiak Island router.
    address public immutable kodiakIslandRouter;

    /// @notice The Kodiak Swap router.
    address public immutable kodiakSwapRouter;

    /// @notice The Kodiak Quoter.
    address public immutable kodiakQuoter;

    uint256 public constant BALANCED_PROPORTION = WAD / 2;

    constructor(address _kodiakIslandRouter, address _kodiakSwapRouter, address _kodiakQuoter) {
        kodiakIslandRouter = _kodiakIslandRouter;
        kodiakSwapRouter = _kodiakSwapRouter;
        kodiakQuoter = _kodiakQuoter;
    }

    /// ADD LIQUIDITY

    /// @notice Add liquidity to an island with an imbalanced ratio. This function will compute the ratios automatically,
    ///         which will make a deposit closer to the optimal ratio and yield a slightly better result, at a significant additional gas cost.
    function addLiquidityImbalanced(
        address island,
        uint256 amount0,
        uint256 amount1,
        uint256 minLPAmount,
        address receiver
    ) external returns (uint256 lpAmount) {
        (address token0, address token1) = _getIslandTokens(island);
        Ratios memory ratios = _getRatios(island, token0, token1, amount0, amount1);
        lpAmount = _addLiquidityImbalanced(island, token0, token1, amount0, amount1, minLPAmount, receiver, ratios);
    }

    /// @notice Add liquidity to an island with an imbalanced ratio. This function accepts ratios that were computed elsewhere.
    function addLiquidityImbalancedAssisted(
        address island,
        uint256 amount0,
        uint256 amount1,
        uint256 minLPAmount,
        address receiver,
        Ratios memory ratios
    ) external returns (uint256 lpAmount) {
        (address token0, address token1) = _getIslandTokens(island);
        lpAmount = _addLiquidityImbalanced(island, token0, token1, amount0, amount1, minLPAmount, receiver, ratios);
    }

    /// @dev Internal function for adding liquidity to an island with an imbalanced ratio.
    function _addLiquidityImbalanced(
        address island,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 minLPAmount,
        address receiver,
        Ratios memory ratios
    ) internal returns (uint256 lpAmount) {
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        uint256 amountIn = _getSwappedAmount(amount0, amount1, ratios);

        uint256 amountOut = _swapExtra(island, token0, token1, amountIn, false, ratios.is0to1);

        uint256 depositAmount0 = ratios.is0to1 ? amount0 - amountIn : amount0 + amountOut;
        uint256 depositAmount1 = ratios.is0to1 ? amount1 + amountOut : amount1 - amountIn;

        IERC20(token0).forceApprove(kodiakIslandRouter, depositAmount0);
        IERC20(token1).forceApprove(kodiakIslandRouter, depositAmount1);

        (,, lpAmount) = IKodiakIslandRouter(kodiakIslandRouter).addLiquidity(
            island, depositAmount0, depositAmount1, 0, 0, minLPAmount, receiver
        );

        _sweepTokens(token0, token1, receiver);
    }

    /// @notice Estimate the amount of LP tokens that will be received when adding liquidity to an island with an imbalanced ratio.
    ///         Also returns precomputed deposit and price ratios to perform a swap during execution.
    function estimateAddLiquidityImbalanced(address island, uint256 amount0, uint256 amount1)
        external
        returns (uint256 lpAmount, Ratios memory ratios)
    {
        (address token0, address token1) = _getIslandTokens(island);

        ratios = _getRatios(island, token0, token1, amount0, amount1);

        uint256 amountIn = _getSwappedAmount(amount0, amount1, ratios);

        uint256 amountOut = _swapExtra(island, token0, token1, amountIn, true, ratios.is0to1);

        uint256 depositAmount0 = ratios.is0to1 ? amount0 - amountIn : amount0 + amountOut;
        uint256 depositAmount1 = ratios.is0to1 ? amount1 + amountOut : amount1 - amountIn;

        (,, lpAmount) = IKodiakIsland(island).getMintAmounts(depositAmount0, depositAmount1);
    }

    /// REMOVE LIQUIDITY

    /// @notice Remove liquidity from an island with an imbalanced ratio. The withdrawal is roughly equivalent to token0proportion * lpAmount
    ///         being withdrawn as token0, and the rest as token1, while minimizing the amount of tokens swapped.
    function removeLiquidityImbalanced(
        address island,
        uint256 lpAmount,
        uint256 token0proportion,
        uint256[2] memory minAmounts,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1) {
        IERC20(island).safeTransferFrom(msg.sender, address(this), lpAmount);

        (address token0, address token1) = _getIslandTokens(island);
        (amount0, amount1) = _removeLiquidity(island, lpAmount);

        (amount0, amount1) = _adjustToProportion(island, token0, token1, amount0, amount1, token0proportion, false);

        (amount0, amount1) = _sweepTokens(token0, token1, receiver);

        if (amount0 < minAmounts[0] || amount1 < minAmounts[1]) revert("KodiakIslandHelper: Insufficient amount");
    }

    /// @dev Internal function to remove balanced liquidity from an island.
    function _removeLiquidity(address island, uint256 lpAmount) internal returns (uint256 amount0, uint256 amount1) {
        IERC20(island).forceApprove(kodiakIslandRouter, lpAmount);
        (amount0, amount1,) =
            IKodiakIslandRouter(kodiakIslandRouter).removeLiquidity(island, lpAmount, 0, 0, address(this));
    }

    /// @notice Estimate the amount of tokens that will be received when removing liquidity from an island with an imbalanced ratio.
    function estimateRemoveLiquidityImbalanced(address island, uint256 lpAmount, uint256 token0proportion)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        (address token0, address token1) = _getIslandTokens(island);

        (uint256 balance0, uint256 balance1) = IKodiakIsland(island).getUnderlyingBalances();

        uint256 totalSupply = IERC20(island).totalSupply();

        amount0 = lpAmount.mulDiv(balance0, totalSupply);
        amount1 = lpAmount.mulDiv(balance1, totalSupply);

        (amount0, amount1) = _adjustToProportion(island, token0, token1, amount0, amount1, token0proportion, true);
    }

    /// HELPERS

    /// @dev Internal function to quote or execute a swap between island tokens.
    function _swapExtra(address island, address token0, address token1, uint256 amountIn, bool isQuote, bool is0to1)
        internal
        returns (uint256 amountOut)
    {
        uint24 fee = IKodiakPool(IKodiakIsland(island).pool()).fee();

        if (isQuote) {
            QuoteExactInputSingleParams memory params = QuoteExactInputSingleParams({
                tokenIn: is0to1 ? token0 : token1,
                tokenOut: is0to1 ? token1 : token0,
                amountIn: amountIn,
                fee: fee,
                sqrtPriceLimitX96: 0
            });

            (amountOut,,,) = IKodiakQuoter(kodiakQuoter).quoteExactInputSingle(params);
        } else {
            ExactInputSingleParams memory params = ExactInputSingleParams({
                tokenIn: is0to1 ? token0 : token1,
                tokenOut: is0to1 ? token1 : token0,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            IERC20(is0to1 ? token0 : token1).forceApprove(kodiakSwapRouter, amountIn);
            amountOut = IKodiakSwapRouter(kodiakSwapRouter).exactInputSingle(params);
        }
    }

    /// @dev Internal function to compute the deposit and price ratios required to balance amounts while adding liquidity.
    function _getRatios(address island, address token0, address token1, uint256 input0, uint256 input1)
        internal
        returns (Ratios memory ratios)
    {
        (uint256 balance0, uint256 balance1) = IKodiakIsland(island).getUnderlyingBalances();
        uint24 fee = IKodiakPool(IKodiakIsland(island).pool()).fee();

        if (balance0 * input1 < balance1 * input0) {
            ratios.depositRatio = balance0.mulDiv(WAD, balance1);

            uint256 amountIn = 10 ** IERC20Metadata(token0).decimals();

            QuoteExactInputSingleParams memory params = QuoteExactInputSingleParams({
                tokenIn: token0,
                tokenOut: token1,
                amountIn: amountIn,
                fee: fee,
                sqrtPriceLimitX96: 0
            });

            (uint256 amountOut,,,) = IKodiakQuoter(kodiakQuoter).quoteExactInputSingle(params);

            ratios.priceRatio = amountOut.mulDiv(WAD, amountIn);

            ratios.is0to1 = true;
        } else {
            ratios.depositRatio = balance1.mulDiv(WAD, balance0);

            uint256 amountIn = 10 ** IERC20Metadata(token1).decimals();

            QuoteExactInputSingleParams memory params = QuoteExactInputSingleParams({
                tokenIn: token1,
                tokenOut: token0,
                amountIn: amountIn,
                fee: fee,
                sqrtPriceLimitX96: 0
            });

            (uint256 amountOut,,,) = IKodiakQuoter(kodiakQuoter).quoteExactInputSingle(params);

            ratios.priceRatio = amountOut.mulDiv(WAD, amountIn);

            ratios.is0to1 = false;
        }
    }

    /// @dev Internal function to swap or get a quote to adjust the amounts to a given proportion.
    function _adjustToProportion(
        address island,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 token0proportion,
        bool isQuote
    ) internal returns (uint256, uint256) {
        uint256 amountIn = 0;
        bool is0to1;

        if (token0proportion < BALANCED_PROPORTION) {
            amountIn = amount0 * (BALANCED_PROPORTION - token0proportion) / WAD;
            is0to1 = true;
        } else {
            amountIn = amount1 * (token0proportion - BALANCED_PROPORTION) / WAD;
            is0to1 = false;
        }

        if (amountIn > 0) {
            uint256 amountOut = _swapExtra(island, token0, token1, amountIn, isQuote, is0to1);

            if (is0to1) {
                amount0 = amount0 - amountIn;
                amount1 = amount1 + amountOut;
            } else {
                amount0 = amount0 + amountOut;
                amount1 = amount1 - amountIn;
            }
        }

        return (amount0, amount1);
    }

    /// @dev Internal function to compute the amount of tokens to swap in order to balance amounts while adding liquidity.
    function _getSwappedAmount(uint256 amount0, uint256 amount1, Ratios memory ratios)
        internal
        pure
        returns (uint256 amountIn)
    {
        if (!ratios.is0to1) (amount0, amount1) = (amount1, amount0);

        uint256 numerator = amount0 - amount1.mulDiv(ratios.depositRatio, WAD);
        uint256 denominator = WAD + ratios.depositRatio.mulDiv(ratios.priceRatio, WAD);

        return numerator.mulDiv(WAD, denominator);
    }

    /// @dev Internal function to get the island tokens.
    function _getIslandTokens(address island) internal view returns (address token0, address token1) {
        token0 = IKodiakIsland(island).token0();
        token1 = IKodiakIsland(island).token1();
    }

    /// @dev Internal function to transfer all remaining island tokens to a receiver.
    function _sweepTokens(address token0, address token1, address receiver)
        internal
        returns (uint256 balance0, uint256 balance1)
    {
        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        if (balance0 > 0) IERC20(token0).safeTransfer(receiver, balance0);
        if (balance1 > 0) IERC20(token1).safeTransfer(receiver, balance1);
    }
}
