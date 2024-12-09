// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";
import {Route} from "../../integrations/equalizer/IEqualizerRouter.sol";

struct EqualizerPool {
    address token0;
    address token1;
    bool stable;
}

struct EqualizerPoolStatus {
    address token0;
    address token1;
    bool stable;
    bool allowed;
}

interface IEqualizerRouterAdapterEvents {
    /// @notice Emited when new status is set for a pair
    event SetPoolStatus(address indexed token0, address indexed token1, bool stable, bool allowed);
}

interface IEqualizerRouterAdapterExceptions {
    /// @notice Thrown when sanity checks on a swap path fail
    error InvalidPathException();
}

/// @title Equalizer Router adapter interface
interface IEqualizerRouterAdapter is IAdapter, IEqualizerRouterAdapterEvents, IEqualizerRouterAdapterExceptions {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address,
        uint256 deadline
    ) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function swapDiffTokensForTokens(
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        Route[] calldata routes,
        uint256 deadline
    ) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function isPoolAllowed(address token0, address token1, bool stable) external view returns (bool);

    function setPoolStatusBatch(EqualizerPoolStatus[] calldata pools) external;

    function supportedPools() external view returns (EqualizerPool[] memory pools);
}
