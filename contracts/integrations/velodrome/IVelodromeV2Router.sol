// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct Route {
    address from;
    address to;
    bool stable;
    address factory;
}

interface IVelodromeV2Router {
    /// @notice Address of FactoryRegistry.sol
    function factoryRegistry() external view returns (address);

    /// @notice Address of Velodrome v2 PoolFactory.sol
    function defaultFactory() external view returns (address);

    /// @notice Perform chained getAmountOut calculations on any number of pools
    function getAmountsOut(uint256 amountIn, Route[] memory routes) external view returns (uint256[] memory amounts);

    // **** SWAP ****

    /// @notice Swap one token for another
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    /// @return amounts     Array of amounts returned per route
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
