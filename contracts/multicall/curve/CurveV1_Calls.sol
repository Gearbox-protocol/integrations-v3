// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";

import {ICurveV1Adapter} from "../../interfaces/curve/ICurveV1Adapter.sol";
import {ICurveV1_2AssetsAdapter} from "../../interfaces/curve/ICurveV1_2AssetsAdapter.sol";
import {ICurveV1_3AssetsAdapter} from "../../interfaces/curve/ICurveV1_3AssetsAdapter.sol";
import {ICurveV1_4AssetsAdapter} from "../../interfaces/curve/ICurveV1_4AssetsAdapter.sol";

interface CurveV1Multicaller {}

library CurveV1Calls {
    function exchange(CurveV1Multicaller c, int128 i, int128 j, uint256 dx, uint256 min_dy)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({target: address(c), callData: abi.encodeCall(ICurveV1Adapter.exchange, (i, j, dx, min_dy))});
    }

    function exchange_all(CurveV1Multicaller c, int128 i, int128 j, uint256 rateMinRAY)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({target: address(c), callData: abi.encodeCall(ICurveV1Adapter.exchange_all, (i, j, rateMinRAY))});
    }

    function exchange_underlying(CurveV1Multicaller c, int128 i, int128 j, uint256 dx, uint256 min_dy)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1Adapter.exchange_underlying, (i, j, dx, min_dy))
        });
    }

    function exchange_all_underlying(CurveV1Multicaller c, int128 i, int128 j, uint256 rateMinRAY)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1Adapter.exchange_all_underlying, (i, j, rateMinRAY))
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

    function add_liquidity_one_coin(CurveV1Multicaller c, uint256 amount, int128 i, uint256 minAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1Adapter.add_liquidity_one_coin, (amount, i, minAmount))
        });
    }

    function add_all_liquidity_one_coin(CurveV1Multicaller c, int128 i, uint256 minRateRAY)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1Adapter.add_all_liquidity_one_coin, (i, minRateRAY))
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

    function remove_liquidity_one_coin(CurveV1Multicaller c, uint256 token_amount, int128 i, uint256 min_amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1Adapter.remove_liquidity_one_coin, (token_amount, i, min_amount))
        });
    }

    function remove_all_liquidity_one_coin(CurveV1Multicaller c, int128 i, uint256 minRateRAY)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(ICurveV1Adapter.remove_all_liquidity_one_coin, (i, minRateRAY))
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
}
