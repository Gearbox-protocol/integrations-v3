// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {ExactInputSingleParams} from "../../integrations/kodiak/IKodiakSwapRouter.sol";
import {Ratios} from "./IKodiakIslandGateway.sol";

enum IslandStatus {
    NOT_ALLOWED,
    ALLOWED,
    SWAP_AND_EXIT_ONLY,
    EXIT_ONLY
}

struct KodiakIslandStatus {
    address island;
    IslandStatus status;
}

interface IKodiakIslandGatewayAdapterExceptions {
    error IslandNotAllowedException(address island);
}

interface IKodiakIslandGatewayAdapter is IAdapter, IKodiakIslandGatewayAdapterExceptions {
    function swap(address island, address tokenIn, uint256 amountIn, uint256 amountOutMin) external returns (bool);

    function swapDiff(address island, address tokenIn, uint256 leftoverAmount, uint256 minRateRAY)
        external
        returns (bool);

    function addLiquidityImbalanced(
        address island,
        uint256 amount0,
        uint256 amount1,
        uint256 minLPAmount,
        address receiver
    ) external returns (bool);

    function addLiquidityImbalancedAssisted(
        address island,
        uint256 amount0,
        uint256 amount1,
        uint256 minLPAmount,
        address receiver,
        Ratios memory ratios
    ) external returns (bool);

    function addLiquidityImbalancedDiff(
        address island,
        uint256 leftoverAmount0,
        uint256 leftoverAmount1,
        uint256[2] memory minRatesRAY
    ) external returns (bool);

    function addLiquidityImbalancedDiffAssisted(
        address island,
        uint256 leftoverAmount0,
        uint256 leftoverAmount1,
        uint256[2] memory minRatesRAY,
        Ratios memory ratios
    ) external returns (bool);

    function removeLiquiditySingle(
        address island,
        uint256 lpAmount,
        address tokenOut,
        uint256 minAmountOut,
        address receiver
    ) external returns (bool);

    function removeLiquiditySingleDiff(address island, uint256 leftoverAmount, address tokenOut, uint256 minRateRAY)
        external
        returns (bool);

    function allowedIslands() external view returns (KodiakIslandStatus[] memory);

    function setIslandStatusBatch(KodiakIslandStatus[] calldata islands) external;
}
