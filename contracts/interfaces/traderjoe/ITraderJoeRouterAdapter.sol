// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Path, Version} from "../../integrations/traderjoe/ITraderJoeRouter.sol";

/// @title TraderJoe Pool definition
struct TraderJoePool {
    address token0;
    address token1;
    uint256 binStep;
    Version poolVersion;
}

/// @title TraderJoe Pool status for configuration
struct TraderJoePoolStatus {
    address token0;
    address token1;
    uint256 binStep;
    Version poolVersion;
    bool allowed;
}

/// @title TraderJoe Router Adapter Interface
interface ITraderJoeRouterAdapter is IAdapter {
    /// @notice Emitted when new status is set for a pool
    event SetPoolStatus(
        address indexed token0, address indexed token1, uint256 binStep, Version poolVersion, bool allowed
    );

    /// @notice Thrown when sanity checks on a swap path fail
    error InvalidPathException();

    /// @notice Swap exact tokens for tokens through TraderJoe paths
    /// @param amountIn Amount of input token to spend
    /// @param amountOutMin Minimum amount of output token to receive
    /// @param path Path struct defining the swap route
    /// @param _to Address to receive the output tokens (ignored, must be credit account)
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Path calldata path,
        address _to,
        uint256 deadline
    ) external returns (bool useSafePrices);

    /// @notice Swap tokens for tokens supporting fee-on-transfer tokens
    /// @param amountIn Amount of input token to spend
    /// @param amountOutMin Minimum amount of output token to receive
    /// @param path Path struct defining the swap route
    /// @param _to Address to receive the output tokens (ignored, must be credit account)
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Path calldata path,
        address _to,
        uint256 deadline
    ) external returns (bool useSafePrices);

    /// @notice Swap all tokens except leftover amount for tokens
    /// @param leftoverAmount Amount of tokenIn to keep on the account
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    /// @param path Path struct defining the swap route
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapDiffTokensForTokens(uint256 leftoverAmount, uint256 rateMinRAY, Path calldata path, uint256 deadline)
        external
        returns (bool useSafePrices);

    /// @notice Swap all tokens except leftover amount for tokens supporting fee-on-transfer tokens
    /// @param leftoverAmount Amount of tokenIn to keep on the account
    /// @param rateMinRAY Minimum exchange rate between input and output tokens, scaled by 1e27
    /// @param path Path struct defining the swap route
    /// @param deadline Maximum timestamp until which the transaction is valid
    function swapDiffTokensForTokensSupportingFeeOnTransferTokens(
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        Path calldata path,
        uint256 deadline
    ) external returns (bool useSafePrices);

    /// @notice Returns all supported pools
    function supportedPools() external view returns (TraderJoePool[] memory pools);

    /// @notice Checks if a specific pool is allowed
    /// @param token0 First token in the pair
    /// @param token1 Second token in the pair
    /// @param binStep Bin step for the pair
    /// @param poolVersion Version of the pair
    function isPoolAllowed(address token0, address token1, uint256 binStep, Version poolVersion)
        external
        view
        returns (bool);

    /// @notice Sets status for a batch of pools
    /// @param pools Array of pool status objects
    function setPoolStatusBatch(TraderJoePoolStatus[] calldata pools) external;
}
