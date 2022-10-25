// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import { ICurvePool } from "../../integrations/curve/ICurvePool.sol";
import { ICurvePool2Assets } from "../../integrations/curve/ICurvePool_2.sol";
import { ICurvePool3Assets } from "../../integrations/curve/ICurvePool_3.sol";
import { ICurvePool4Assets } from "../../integrations/curve/ICurvePool_4.sol";
import { ICurveV1Adapter } from "../../interfaces/curve/ICurveV1Adapter.sol";

interface CurveV1Multicaller {}

library CurveV1Calls {
    function exchange(
        CurveV1Multicaller c,
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool.exchange.selector,
                    i,
                    j,
                    dx,
                    min_dy
                )
            });
    }

    function exchange_all(
        CurveV1Multicaller c,
        int128 i,
        int128 j,
        uint256 rateMinRAY
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurveV1Adapter.exchange_all.selector,
                    i,
                    j,
                    rateMinRAY
                )
            });
    }

    function exchange_underlying(
        CurveV1Multicaller c,
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool.exchange_underlying.selector,
                    i,
                    j,
                    dx,
                    min_dy
                )
            });
    }

    function exchange_all_underlying(
        CurveV1Multicaller c,
        int128 i,
        int128 j,
        uint256 rateMinRAY
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurveV1Adapter.exchange_all_underlying.selector,
                    i,
                    j,
                    rateMinRAY
                )
            });
    }

    function add_liquidity(
        CurveV1Multicaller c,
        uint256[2] calldata amounts,
        uint256 min_mint_amount
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool2Assets.add_liquidity.selector,
                    amounts,
                    min_mint_amount
                )
            });
    }

    function add_liquidity(
        CurveV1Multicaller c,
        uint256[3] calldata amounts,
        uint256 min_mint_amount
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool3Assets.add_liquidity.selector,
                    amounts,
                    min_mint_amount
                )
            });
    }

    function add_liquidity(
        CurveV1Multicaller c,
        uint256[4] calldata amounts,
        uint256 min_mint_amount
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool4Assets.add_liquidity.selector,
                    amounts,
                    min_mint_amount
                )
            });
    }

    function add_liquidity_one_coin(
        CurveV1Multicaller c,
        uint256 amount,
        int128 i,
        uint256 minAmount
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurveV1Adapter.add_liquidity_one_coin.selector,
                    amount,
                    i,
                    minAmount
                )
            });
    }

    function add_all_liquidity_one_coin(
        CurveV1Multicaller c,
        int128 i,
        uint256 minRateRAY
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurveV1Adapter.add_all_liquidity_one_coin.selector,
                    i,
                    minRateRAY
                )
            });
    }

    function remove_liquidity(
        CurveV1Multicaller c,
        uint256 amount,
        uint256[2] calldata min_amounts
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool2Assets.remove_liquidity.selector,
                    amount,
                    min_amounts
                )
            });
    }

    function remove_liquidity(
        CurveV1Multicaller c,
        uint256 amount,
        uint256[3] calldata min_amounts
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool3Assets.remove_liquidity.selector,
                    amount,
                    min_amounts
                )
            });
    }

    function remove_liquidity(
        CurveV1Multicaller c,
        uint256 amount,
        uint256[4] calldata min_amounts
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool4Assets.remove_liquidity.selector,
                    amount,
                    min_amounts
                )
            });
    }

    function remove_liquidity_one_coin(
        CurveV1Multicaller c,
        uint256 token_amount,
        int128 i,
        uint256 min_amount
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool.remove_liquidity_one_coin.selector,
                    token_amount,
                    i,
                    min_amount
                )
            });
    }

    function remove_all_liquidity_one_coin(
        CurveV1Multicaller c,
        int128 i,
        uint256 minRateRAY
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurveV1Adapter.remove_all_liquidity_one_coin.selector,
                    i,
                    minRateRAY
                )
            });
    }

    function remove_liquidity_imbalance(
        CurveV1Multicaller c,
        uint256[2] calldata amounts,
        uint256 max_burn_amount
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool2Assets.remove_liquidity_imbalance.selector,
                    amounts,
                    max_burn_amount
                )
            });
    }

    function remove_liquidity_imbalance(
        CurveV1Multicaller c,
        uint256[3] calldata amounts,
        uint256 max_burn_amount
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool3Assets.remove_liquidity_imbalance.selector,
                    amounts,
                    max_burn_amount
                )
            });
    }

    function remove_liquidity_imbalance(
        CurveV1Multicaller c,
        uint256[4] calldata amounts,
        uint256 max_burn_amount
    ) internal pure returns (MultiCall memory) {
        return
            MultiCall({
                target: address(c),
                callData: abi.encodeWithSelector(
                    ICurvePool4Assets.remove_liquidity_imbalance.selector,
                    amounts,
                    max_burn_amount
                )
            });
    }
}
