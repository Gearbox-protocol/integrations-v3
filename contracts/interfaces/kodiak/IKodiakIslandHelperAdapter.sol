// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {Ratios} from "./IKodiakIslandHelper.sol";

enum IslandStatus {
    ALLOWED,
    EXIT_ONLY,
    NOT_ALLOWED
}

struct KodiakIslandStatus {
    address island;
    IslandStatus status;
}

interface IKodiakIslandHelperAdapterExceptions {
    error IslandNotAllowedException(address island);
}

interface IKodiakIslandHelperAdapter is IAdapter, IKodiakIslandHelperAdapterExceptions {
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

    function removeLiquidityImbalanced(
        address island,
        uint256 lpAmount,
        uint256 token0proportion,
        uint256[2] memory minAmounts,
        address receiver
    ) external returns (bool);

    function removeLiquidityImbalancedDiff(
        address island,
        uint256 leftoverLPAmount,
        uint256 token0proportion,
        uint256[2] memory minRatesRAY
    ) external returns (bool);

    function allowedIslands() external view returns (KodiakIslandStatus[] memory);

    function setIslandStatusBatch(KodiakIslandStatus[] calldata islands) external;
}
