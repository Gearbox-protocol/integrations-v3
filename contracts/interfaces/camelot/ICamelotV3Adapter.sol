// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

import {ICamelotV3Router} from "../../integrations/camelot/ICamelotV3Router.sol";

struct CamelotV3PoolStatus {
    address token0;
    address token1;
    bool allowed;
}

interface ICamelotV3AdapterTypes {
    /// @notice Params for exact diff input swap through a single pool
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param deadline Maximum timestamp until which the transaction is valid
    /// @param leftoverAmount Amount of tokenIn to keep on the account
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    /// @param limitSqrtPrice Maximum execution price, ignored if 0
    struct ExactDiffInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 deadline;
        uint256 leftoverAmount;
        uint256 rateMinRAY;
        uint160 limitSqrtPrice;
    }

    /// @notice Params for exact diff input swap through multiple pools
    /// @param path Bytes-encoded swap path, see Camelot docs for details
    /// @param deadline Maximum timestamp until which the transaction is valid
    /// @param leftoverAmount Amount of tokenIn to keep on the account
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    struct ExactDiffInputParams {
        bytes path;
        uint256 deadline;
        uint256 leftoverAmount;
        uint256 rateMinRAY;
    }
}

interface ICamelotV3AdapterEvents {
    /// @notice Emitted when new status is set for a pool
    event SetPoolStatus(address indexed token0, address indexed token1, bool allowed);
}

interface ICamelotV3AdapterExceptions {
    /// @notice Thrown when sanity checks on a swap path fail
    error InvalidPathException();
}

/// @title Camelot V3 Router adapter interface
interface ICamelotV3Adapter is
    IAdapter,
    ICamelotV3AdapterTypes,
    ICamelotV3AdapterEvents,
    ICamelotV3AdapterExceptions
{
    function exactInputSingle(ICamelotV3Router.ExactInputSingleParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactDiffInputSingle(ExactDiffInputSingleParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactInputSingleSupportingFeeOnTransferTokens(ICamelotV3Router.ExactInputSingleParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactDiffInputSingleSupportingFeeOnTransferTokens(ExactDiffInputSingleParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactInput(ICamelotV3Router.ExactInputParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactDiffInput(ExactDiffInputParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactOutputSingle(ICamelotV3Router.ExactOutputSingleParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function exactOutput(ICamelotV3Router.ExactOutputParams calldata params)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function isPoolAllowed(address token0, address token1) external view returns (bool);

    function setPoolStatusBatch(CamelotV3PoolStatus[] calldata pools) external;
}
