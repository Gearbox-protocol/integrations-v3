// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAdapter, AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {N_COINS} from "../../integrations/curve/ICurvePool_2.sol";
import {ICurveV1Adapter} from "../../interfaces/curve/ICurveV1Adapter.sol";
import {CurveV1AdapterBase} from "./CurveV1_Base.sol";
import {CurveV1Adapter2Assets} from "./CurveV1_2.sol";

/// @title Curve V1 stETH adapter
/// @notice Same as CurveV1Adapter2Assets but uses stETH gateway and needs to approve LP token
contract CurveV1AdapterStETH is CurveV1Adapter2Assets {
    function _gearboxAdapterType() external pure override returns (AdapterType) {
        return AdapterType.CURVE_V1_STECRV_POOL;
    }

    /// @notice Sets allowance for the pool LP token to max before the operation and to 1 after
    modifier withLPTokenApproval() {
        _approveToken(lp_token, type(uint256).max);
        _;
        _approveToken(lp_token, 1);
    }

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _curveStETHPoolGateway steCRV pool gateway address
    /// @param _lp_token steCRV LP token address
    constructor(address _creditManager, address _curveStETHPoolGateway, address _lp_token)
        CurveV1Adapter2Assets(_creditManager, _curveStETHPoolGateway, _lp_token, address(0))
    {}

    /// @notice Remove liquidity from the pool
    /// @dev '_amount' and 'min_amounts' parameters are ignored because calldata is directly passed to the target contract
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_liquidity(uint256, uint256[N_COINS] calldata)
        external
        override
        creditFacadeOnly
        withLPTokenApproval // F: [ACV1S-2]
    {
        _remove_liquidity(); // F: [ACV1S-2]
    }

    /// @notice Removes liquidity from the pool in a specified asset
    /// @param i Index of the asset to withdraw
    /// @dev `_token_amount` and `min_amount` parameters are ignored because calldata is passed directly to the target contract
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_liquidity_one_coin(uint256, int128 i, uint256)
        public
        override(CurveV1AdapterBase, ICurveV1Adapter)
        creditFacadeOnly
        withLPTokenApproval // F: [ACV1S-4]
    {
        _remove_liquidity_one_coin(i); // F: [ACV1S-4]
    }

    /// @notice Removes all liquidity from the pool in a specified asset
    /// @param i Index of the asset to withdraw
    /// @param rateMinRAY Minimum exchange rate between LP token and received token
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_all_liquidity_one_coin(int128 i, uint256 rateMinRAY)
        public
        override(CurveV1AdapterBase, ICurveV1Adapter)
        creditFacadeOnly
        withLPTokenApproval // F: [ACV1S-5]
    {
        _remove_all_liquidity_one_coin(i, rateMinRAY); // F: [ACV1S-5]
    }

    /// @notice Withdraw exact amounts of tokens from the pool
    /// @param amounts Amounts of tokens to withdraw
    /// @dev `max_burn_amount` parameter is ignored because calldata is directly passed to the target contract
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_liquidity_imbalance(uint256[N_COINS] calldata amounts, uint256)
        external
        override
        creditFacadeOnly
        withLPTokenApproval // F: [ACV1S-6]
    {
        _remove_liquidity_imbalance(amounts[0] > 1, amounts[1] > 1, false, false); // F: [ACV1S-6]
    }
}
