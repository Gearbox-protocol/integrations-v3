// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBalancerV3RouterAdapter} from "../../../interfaces/balancer/IBalancerV3RouterAdapter.sol";

interface BalancerV3Router_Multicaller {}

library BalancerV3Router_Calls {
    function swapSingleTokenExactIn(
        BalancerV3Router_Multicaller c,
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool wethIsEth,
        bytes memory userData
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IBalancerV3RouterAdapter.swapSingleTokenExactIn,
                (pool, tokenIn, tokenOut, exactAmountIn, minAmountOut, deadline, wethIsEth, userData)
            )
        });
    }

    function swapSingleTokenDiffIn(
        BalancerV3Router_Multicaller c,
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IBalancerV3RouterAdapter.swapSingleTokenDiffIn,
                (pool, tokenIn, tokenOut, leftoverAmount, rateMinRAY, deadline)
            )
        });
    }
}
