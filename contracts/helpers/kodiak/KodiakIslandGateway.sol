// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {IKodiakIslandGateway, Ratios} from "../../interfaces/kodiak/IKodiakIslandGateway.sol";
import {IKodiakIsland, IKodiakPool} from "../../integrations/kodiak/IKodiakIsland.sol";
import {IKodiakIslandRouter} from "../../integrations/kodiak/IKodiakIslandRouter.sol";
import {IKodiakQuoter, QuoteExactInputSingleParams} from "../../integrations/kodiak/IKodiakQuoter.sol";
import {IKodiakSwapRouter, ExactInputSingleParams} from "../../integrations/kodiak/IKodiakSwapRouter.sol";

contract KodiakIslandGateway is IKodiakIslandGateway {
    using SafeERC20 for IERC20;
    using Math for uint256;

    bytes32 public immutable contractType = "GATEWAY::KODIAK_ISLAND";
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

    /// SWAP

    function swap(address island, address tokenIn, uint256 amountIn, uint256 amountOutMin)
        external
        returns (uint256 amountOut)
    {
        (address token0, address token1) = _getIslandTokens(island);

        if (tokenIn != token0 && tokenIn != token1) revert("KodiakIslandGateway: Invalid tokenIn");

        uint24 fee = IKodiakPool(IKodiakIsland(island).pool()).fee();

        ExactInputSingleParams memory params = ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenIn == token0 ? token1 : token0,
            fee: fee,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).forceApprove(kodiakSwapRouter, amountIn);
        amountOut = IKodiakSwapRouter(kodiakSwapRouter).exactInputSingle(params);
    }

    function estimateSwap(address island, address tokenIn, uint256 amountIn) external returns (uint256 amountOut) {
        (address token0, address token1) = _getIslandTokens(island);
        if (tokenIn != token0 && tokenIn != token1) revert("KodiakIslandGateway: Invalid tokenIn");

        uint24 fee = IKodiakPool(IKodiakIsland(island).pool()).fee();

        QuoteExactInputSingleParams memory params = QuoteExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenIn == token0 ? token1 : token0,
            amountIn: amountIn,
            fee: fee,
            sqrtPriceLimitX96: 0
        });

        (amountOut,,,) = IKodiakQuoter(kodiakQuoter).quoteExactInputSingle(params);
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

        lpAmount = _getSwapAdjustedMintAmounts(island, amountIn, amountOut, depositAmount0, depositAmount1, ratios);
    }

    /// REMOVE LIQUIDITY

    function removeLiquiditySingle(
        address island,
        uint256 lpAmount,
        address tokenOut,
        uint256 minAmountOut,
        address receiver
    ) external returns (uint256 amountOut) {
        IERC20(island).safeTransferFrom(msg.sender, address(this), lpAmount);

        (uint256 amount0, uint256 amount1) = _removeLiquidity(island, lpAmount);

        (address token0, address token1) = _getIslandTokens(island);

        bool is0to1 = tokenOut == token1;

        _swapExtra(island, token0, token1, is0to1 ? amount0 : amount1, false, is0to1);

        (amount0, amount1) = _sweepTokens(token0, token1, receiver);

        amountOut = is0to1 ? amount1 : amount0;

        if (amountOut < minAmountOut) revert("KodiakIslandGateway: Insufficient amount");

        return amountOut;
    }

    /// @dev Internal function to remove balanced liquidity from an island.
    function _removeLiquidity(address island, uint256 lpAmount) internal returns (uint256 amount0, uint256 amount1) {
        IERC20(island).forceApprove(kodiakIslandRouter, lpAmount);
        (amount0, amount1,) =
            IKodiakIslandRouter(kodiakIslandRouter).removeLiquidity(island, lpAmount, 0, 0, address(this));
    }

    /// @notice Estimate the amount of tokens that will be received when removing liquidity from an island with an imbalanced ratio.
    function estimateRemoveLiquiditySingle(address island, uint256 lpAmount, address tokenOut)
        external
        returns (uint256 amountOut)
    {
        (address token0, address token1) = _getIslandTokens(island);

        (uint256 balance0, uint256 balance1) = IKodiakIsland(island).getUnderlyingBalances();

        uint256 totalSupply = IERC20(island).totalSupply();

        uint256 amount0 = lpAmount.mulDiv(balance0, totalSupply);
        uint256 amount1 = lpAmount.mulDiv(balance1, totalSupply);

        bool is0to1 = tokenOut == token1;

        amountOut = _swapExtra(island, token0, token1, is0to1 ? amount0 : amount1, true, is0to1);

        amountOut += is0to1 ? amount1 : amount0;
    }

    /// HELPERS

    /// @dev Internal function to quote or execute a swap between island tokens.
    function _swapExtra(address island, address token0, address token1, uint256 amountIn, bool isQuote, bool is0to1)
        internal
        returns (uint256 amountOut)
    {
        if (amountIn == 0) return 0;

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
    /// @return ratios A struct with three values:
    ///         - depositRatio: The ratio of the underlying balances of token0 and token1, which a balanced deposit must satisfy.
    ///         - priceRatio: The exchange price between token0 and token1, which is determined by querying a swap with one unit of the token.
    ///         - is0to1: Whether token0 needs to be swapped to token1, or vice versa.
    function _getRatios(address island, address token0, address token1, uint256 input0, uint256 input1)
        internal
        returns (Ratios memory ratios)
    {
        (uint256 balance0, uint256 balance1) = IKodiakIsland(island).getUnderlyingBalances();

        ratios.balance0 = balance0;
        ratios.balance1 = balance1;

        /// If the current price is outside the Kodiak Island range, we need to swap one token to another entirely
        if (balance0 == 0) {
            ratios.swapAll = true;
            ratios.is0to1 = true;
            return ratios;
        } else if (balance1 == 0) {
            ratios.swapAll = true;
            ratios.is0to1 = false;
            return ratios;
        }

        uint24 fee = IKodiakPool(IKodiakIsland(island).pool()).fee();

        /// If amount0 / amount1 is greater than the required deposit ratio of the island, then we need to swap token0 to token1.
        /// Otherwise, we need to swap token1 to token0.
        if (balance0 * input1 < balance1 * input0) {
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

    /// @dev Internal function to compute the amount of tokens to swap in order to balance amounts while adding liquidity.
    /// @dev This returns a solution to the equation (x - dx) / (y + dx * p) = r.
    function _getSwappedAmount(uint256 amount0, uint256 amount1, Ratios memory ratios)
        internal
        pure
        returns (uint256 amountIn)
    {
        if (ratios.swapAll) return ratios.is0to1 ? amount0 : amount1;

        if (!ratios.is0to1) (amount0, amount1) = (amount1, amount0);

        (uint256 balance0, uint256 balance1) = (ratios.balance0, ratios.balance1);

        if (!ratios.is0to1) (balance0, balance1) = (balance1, balance0);

        uint256 numerator = amount0 * balance1 - amount1 * balance0;
        uint256 denominator = (amount0 + balance0).mulDiv(ratios.priceRatio, WAD) + balance1 + amount1;

        return numerator / denominator;
    }

    /// @dev Computes amount of tokens that will be minted with updated island balances after the swap
    /// @dev In the case where the swap moves the price outside the Island range, we approximate the change in the second token's balance
    ///      proportionally to the remaining capacity in the first token. Otherwise, we update with exact amounts.
    function _getSwapAdjustedMintAmounts(
        address island,
        uint256 amountIn,
        uint256 amountOut,
        uint256 depositAmount0,
        uint256 depositAmount1,
        Ratios memory ratios
    ) internal view returns (uint256 lpAmount) {
        (uint256 balance0, uint256 balance1) = (ratios.balance0, ratios.balance1);

        if (ratios.is0to1) {
            if (balance1 < amountOut) {
                balance0 = balance0 + balance1 * amountIn / amountOut;
                balance1 = 0;
            } else {
                balance0 = balance0 + amountIn;
                balance1 = balance1 - amountOut;
            }
        } else {
            if (balance0 < amountOut) {
                balance1 = balance1 + balance0 * amountIn / amountOut;
                balance0 = 0;
            } else {
                balance0 = balance0 - amountOut;
                balance1 = balance1 + amountIn;
            }
        }

        uint256 totalSupply = IERC20(island).totalSupply();

        if (balance0 == 0) {
            lpAmount == depositAmount1 * totalSupply / balance1;
        } else if (balance1 == 0) {
            lpAmount == depositAmount0 * totalSupply / balance0;
        } else {
            uint256 amount0Mint = depositAmount0 * totalSupply / balance0;
            uint256 amount1Mint = depositAmount1 * totalSupply / balance1;

            lpAmount = amount0Mint < amount1Mint ? amount0Mint : amount1Mint;
        }
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

        if (balance0 > 1) IERC20(token0).safeTransfer(receiver, balance0 - 1);
        if (balance1 > 1) IERC20(token1).safeTransfer(receiver, balance1 - 1);
    }
}
