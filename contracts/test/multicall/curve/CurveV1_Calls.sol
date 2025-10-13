// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024
pragma solidity ^0.8.23;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

import {ICurveV1Adapter} from "../../../interfaces/curve/ICurveV1Adapter.sol";
import {ICurveV1_2AssetsAdapter} from "../../../interfaces/curve/ICurveV1_2AssetsAdapter.sol";
import {ICurveV1_3AssetsAdapter} from "../../../interfaces/curve/ICurveV1_3AssetsAdapter.sol";
import {ICurveV1_4AssetsAdapter} from "../../../interfaces/curve/ICurveV1_4AssetsAdapter.sol";
import {ICurveV1_StableNGAdapter} from "../../../interfaces/curve/ICurveV1_StableNGAdapter.sol";

interface CurveV1Multicaller {}

library CurveV1Calls {
    function exchange(CurveV1Multicaller c, int128 i, int128 j, uint256 dx, uint256 min_dy)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)", i, j, dx, min_dy)
        });
    }

    function exchange(CurveV1Multicaller c, uint256 i, uint256 j, uint256 dx, uint256 min_dy)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature("exchange(uint256,uint256,uint256,uint256)", i, j, dx, min_dy)
        });
    }

    function exchange_diff(CurveV1Multicaller c, uint256 i, uint256 j, uint256 leftoverAmount, uint256 rateMinRAY)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature(
                "exchange_diff(uint256,uint256,uint256,uint256)", i, j, leftoverAmount, rateMinRAY
            )
        });
    }

    function exchange_underlying(CurveV1Multicaller c, int128 i, int128 j, uint256 dx, uint256 min_dy)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature("exchange_underlying(int128,int128,uint256,uint256)", i, j, dx, min_dy)
        });
    }

    function exchange_underlying(CurveV1Multicaller c, uint256 i, uint256 j, uint256 dx, uint256 min_dy)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature("exchange_underlying(uint256,uint256,uint256,uint256)", i, j, dx, min_dy)
        });
    }

    function exchange_diff_underlying(
        CurveV1Multicaller c,
        uint256 i,
        uint256 j,
        uint256 leftoverAmount,
        uint256 rateMinRAY
    ) internal pure returns (MultiCall memory) {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature(
                "exchange_diff_underlying(uint256,uint256,uint256,uint256)", i, j, leftoverAmount, rateMinRAY
            )
        });
    }

    function add_liquidity(CurveV1Multicaller c, uint256[2] memory amounts, uint256 min_mint_amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_2AssetsAdapter.add_liquidity, (amounts, min_mint_amount))
        });
    }

    function add_liquidity(CurveV1Multicaller c, uint256[3] memory amounts, uint256 min_mint_amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_3AssetsAdapter.add_liquidity, (amounts, min_mint_amount))
        });
    }

    function add_liquidity(CurveV1Multicaller c, uint256[4] memory amounts, uint256 min_mint_amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_4AssetsAdapter.add_liquidity, (amounts, min_mint_amount))
        });
    }

    function add_liquidity(CurveV1Multicaller c, uint256[] memory amounts, uint256 min_mint_amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_StableNGAdapter.add_liquidity, (amounts, min_mint_amount))
        });
    }

    function add_liquidity_one_coin(CurveV1Multicaller c, uint256 amount, uint256 i, uint256 minAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature("add_liquidity_one_coin(uint256,uint256,uint256)", amount, i, minAmount)
        });
    }

    function add_diff_liquidity_one_coin(CurveV1Multicaller c, uint256 leftoverAmount, uint256 i, uint256 rateMinRAY)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature(
                "add_diff_liquidity_one_coin(uint256,uint256,uint256)", leftoverAmount, i, rateMinRAY
            )
        });
    }

    function remove_liquidity(CurveV1Multicaller c, uint256 amount, uint256[2] memory min_amounts)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_2AssetsAdapter.remove_liquidity, (amount, min_amounts))
        });
    }

    function remove_liquidity(CurveV1Multicaller c, uint256 amount, uint256[3] memory min_amounts)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_3AssetsAdapter.remove_liquidity, (amount, min_amounts))
        });
    }

    function remove_liquidity(CurveV1Multicaller c, uint256 amount, uint256[4] memory min_amounts)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_4AssetsAdapter.remove_liquidity, (amount, min_amounts))
        });
    }

    function remove_liquidity(CurveV1Multicaller c, uint256 amount, uint256[] memory min_amounts)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_StableNGAdapter.remove_liquidity, (amount, min_amounts))
        });
    }

    function remove_liquidity_one_coin(CurveV1Multicaller c, uint256 token_amount, int128 i, uint256 min_amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature(
                "remove_liquidity_one_coin(uint256,int128,uint256)", token_amount, i, min_amount
            )
        });
    }

    function remove_liquidity_one_coin(CurveV1Multicaller c, uint256 token_amount, uint256 i, uint256 min_amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature(
                "remove_liquidity_one_coin(uint256,uint256,uint256)", token_amount, i, min_amount
            )
        });
    }

    function remove_diff_liquidity_one_coin(CurveV1Multicaller c, uint256 leftoverAmount, uint256 i, uint256 rateMinRAY)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeWithSignature(
                "remove_diff_liquidity_one_coin(uint256,uint256,uint256)", leftoverAmount, i, rateMinRAY
            )
        });
    }

    function remove_liquidity_imbalance(CurveV1Multicaller c, uint256[2] memory amounts, uint256 max_burn_amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_2AssetsAdapter.remove_liquidity_imbalance, (amounts, max_burn_amount))
        });
    }

    function remove_liquidity_imbalance(CurveV1Multicaller c, uint256[3] memory amounts, uint256 max_burn_amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_3AssetsAdapter.remove_liquidity_imbalance, (amounts, max_burn_amount))
        });
    }

    function remove_liquidity_imbalance(CurveV1Multicaller c, uint256[4] memory amounts, uint256 max_burn_amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_4AssetsAdapter.remove_liquidity_imbalance, (amounts, max_burn_amount))
        });
    }

    function remove_liquidity_imbalance(CurveV1Multicaller c, uint256[] memory amounts, uint256 max_burn_amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1_StableNGAdapter.remove_liquidity_imbalance, (amounts, max_burn_amount))
        });
    }
}
