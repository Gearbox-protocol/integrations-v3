// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {ICurveV1Adapter} from "./ICurveV1Adapter.sol";
import {N_COINS} from "../../integrations/curve/ICurvePool_2.sol";

interface ICurveV1_2AssetsAdapter is ICurveV1Adapter {
    /// @dev Sends an order to add liquidity to a Curve pool
    /// @param amounts Amounts of tokens to add
    /// @notice 'min_mint_amount' is ignored since the calldata is routed directly to the target
    /// @notice Internal implementation details in CurveV1Base
    function add_liquidity(uint256[N_COINS] calldata amounts, uint256) external;

    /// @dev Sends an order to remove liquidity from a Curve pool
    /// @notice '_amount' and 'min_amounts' are ignored since the calldata is routed directly to the target
    /// @notice Internal implementation details in CurveV1Base
    function remove_liquidity(uint256, uint256[N_COINS] calldata) external;

    /// @dev Sends an order to remove liquidity from a Curve pool in exact token amounts
    /// @param amounts Amounts of coins to withdraw
    /// @notice `max_burn_amount` is ignored since the calldata is routed directly to the target
    /// @notice Internal implementation details in CurveV1Base
    function remove_liquidity_imbalance(uint256[N_COINS] calldata amounts, uint256) external;
}
