// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { IAdapter, AdapterType } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import { N_COINS } from "../../integrations/curve/ICurvePool_4.sol";
import { ICurveV1_4AssetsAdapter } from "../../interfaces/curve/ICurveV1_4AssetsAdapter.sol";
import { CurveV1AdapterBase } from "./CurveV1_Base.sol";

/// @title CurveV1Adapter4Assets adapter
/// @dev Implements logic for interacting with a Curve pool with 4 assets
contract CurveV1Adapter4Assets is CurveV1AdapterBase, ICurveV1_4AssetsAdapter {
    AdapterType
        public constant
        override(CurveV1AdapterBase, IAdapter) _gearboxAdapterType =
        AdapterType.CURVE_V1_4ASSETS;

    /// @dev Constructor
    /// @param _creditManager Address of the Credit manager
    /// @param _curvePool Address of the target contract Curve pool
    /// @param _lp_token Address of the pool's LP token
    /// @param _metapoolBase The base pool if this pool is a metapool, otherwise 0x0
    constructor(
        address _creditManager,
        address _curvePool,
        address _lp_token,
        address _metapoolBase
    )
        CurveV1AdapterBase(
            _creditManager,
            _curvePool,
            _lp_token,
            _metapoolBase,
            N_COINS
        )
    {}

    /// @dev Sends an order to add liquidity to a Curve pool
    /// @param amounts Amounts of tokens to add
    /// @notice 'min_mint_amount' is ignored since the calldata is routed directly to the target
    /// @notice Internal implementation details in CurveV1Base
    function add_liquidity(
        uint256[N_COINS] calldata amounts,
        uint256
    ) external creditFacadeOnly {
        _add_liquidity(
            amounts[0] > 1,
            amounts[1] > 1,
            amounts[2] > 1,
            amounts[3] > 1
        ); // F:[ACV1_4-4]
    }

    /// @dev Sends an order to remove liquidity from a Curve pool
    /// @notice '_amount' and 'min_amounts' are ignored since the calldata is routed directly to the target
    /// @notice Internal implementation details in CurveV1Base
    function remove_liquidity(
        uint256,
        uint256[N_COINS] calldata
    ) external virtual creditFacadeOnly {
        _remove_liquidity(); // F:[ACV1_4-5]
    }

    /// @dev Sends an order to remove liquidity from a Curve pool in exact token amounts
    /// @param amounts Amounts of coins to withdraw
    /// @notice `max_burn_amount` is ignored since the calldata is routed directly to the target
    /// @notice Internal implementation details in CurveV1Base
    function remove_liquidity_imbalance(
        uint256[N_COINS] calldata amounts,
        uint256
    ) external virtual override creditFacadeOnly {
        _remove_liquidity_imbalance(
            amounts[0] > 1,
            amounts[1] > 1,
            amounts[2] > 1,
            amounts[3] > 1
        ); // F:[ACV1_4-6]
    }
}
