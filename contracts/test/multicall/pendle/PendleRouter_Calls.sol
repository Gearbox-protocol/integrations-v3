// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {
    IPendleRouterAdapter, TokenDiffInput, TokenDiffOutput
} from "../../../interfaces/pendle/IPendleRouterAdapter.sol";
import {TokenInput, TokenOutput, ApproxParams, LimitOrderData} from "../../../integrations/pendle/IPendleRouter.sol";

interface PendleRouter_Multicaller {}

library PendleRouter_Calls {
    function swapExactTokenForPt(
        PendleRouter_Multicaller c,
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams memory guessPtOut,
        TokenInput memory input,
        LimitOrderData memory limitOrderData
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IPendleRouterAdapter.swapExactTokenForPt, (receiver, market, minPtOut, guessPtOut, input, limitOrderData)
            )
        });
    }

    function swapDiffTokenForPt(
        PendleRouter_Multicaller c,
        address market,
        uint256 minRateRAY,
        ApproxParams memory guessPtOut,
        TokenDiffInput memory diffInput
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IPendleRouterAdapter.swapDiffTokenForPt, (market, minRateRAY, guessPtOut, diffInput))
        });
    }

    function swapExactPtForToken(
        PendleRouter_Multicaller c,
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput memory output,
        LimitOrderData memory limitOrderData
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(
                IPendleRouterAdapter.swapExactPtForToken, (receiver, market, exactPtIn, output, limitOrderData)
            )
        });
    }

    function swapDiffPtForToken(
        PendleRouter_Multicaller c,
        address market,
        uint256 leftoverPt,
        TokenDiffOutput memory diffOutput
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IPendleRouterAdapter.swapDiffPtForToken, (market, leftoverPt, diffOutput))
        });
    }

    function redeemPyToToken(
        PendleRouter_Multicaller c,
        address receiver,
        address yt,
        uint256 netPyIn,
        TokenOutput memory output
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IPendleRouterAdapter.redeemPyToToken, (receiver, yt, netPyIn, output))
        });
    }

    function redeemDiffPyToToken(
        PendleRouter_Multicaller c,
        address yt,
        uint256 leftoverPt,
        TokenDiffOutput memory diffOutput
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IPendleRouterAdapter.redeemDiffPyToToken, (yt, leftoverPt, diffOutput))
        });
    }
}
