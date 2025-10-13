// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IVelodromeV2RouterAdapter} from "../../../interfaces/velodrome/IVelodromeV2RouterAdapter.sol";
import {Route} from "../../../integrations/velodrome/IVelodromeV2Router.sol";

interface VelodromeV2Router_Multicaller {}

library VelodromeV2Router_Calls {
    function swapExactTokensForTokens(
        VelodromeV2Router_Multicaller c,
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] memory routes,
        address,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IVelodromeV2RouterAdapter.swapExactTokensForTokens, (amountIn, amountOutMin, routes, address(0), deadline)
            )
        });
    }

    function swapDiffTokensForTokens(
        VelodromeV2Router_Multicaller c,
        uint256 leftoverAmount,
        uint256 rateMinRAY,
        Route[] memory routes,
        uint256 deadline
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IVelodromeV2RouterAdapter.swapDiffTokensForTokens, (leftoverAmount, rateMinRAY, routes, deadline)
            )
        });
    }
}
