// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {N_COINS} from "../../integrations/curve/ICurvePool_2.sol";
import {ICurveV1Adapter} from "../../interfaces/curve/ICurveV1Adapter.sol";
import {CurveV1AdapterBase} from "./CurveV1_Base.sol";
import {CurveV1Adapter2Assets} from "./CurveV1_2.sol";

/// @title Curve V1 stETH adapter
/// @notice Same as `CurveV1Adapter2Assets` but uses stETH gateway and needs to approve LP token
contract CurveV1AdapterStETH is CurveV1Adapter2Assets {
    bytes32 public constant override contractType = "ADAPTER::CURVE_V1_STECRV_POOL";

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

    /// @inheritdoc CurveV1Adapter2Assets
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_liquidity(uint256, uint256[N_COINS] calldata)
        external
        override
        creditFacadeOnly
        withLPTokenApproval
        returns (bool)
    {
        _execute(msg.data);
        return true;
    }

    /// @inheritdoc CurveV1Adapter2Assets
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_liquidity_imbalance(uint256[N_COINS] calldata, uint256)
        external
        override
        creditFacadeOnly
        withLPTokenApproval
        returns (bool)
    {
        _execute(msg.data);
        return true;
    }

    /// @inheritdoc CurveV1AdapterBase
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_liquidity_one_coin(uint256 amount, uint256 i, uint256 minAmount)
        public
        override(CurveV1AdapterBase, ICurveV1Adapter)
        creditFacadeOnly
        withLPTokenApproval
        returns (bool)
    {
        _remove_liquidity_one_coin(amount, i, minAmount);
        return true;
    }

    /// @inheritdoc CurveV1AdapterBase
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_liquidity_one_coin(uint256 amount, int128 i, uint256 minAmount)
        public
        override(CurveV1AdapterBase, ICurveV1Adapter)
        creditFacadeOnly
        withLPTokenApproval
        returns (bool)
    {
        _remove_liquidity_one_coin(amount, _toU256(i), minAmount);
        return true;
    }

    /// @inheritdoc CurveV1AdapterBase
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_diff_liquidity_one_coin(uint256 leftoverAmount, uint256 i, uint256 rateMinRAY)
        public
        override(CurveV1AdapterBase, ICurveV1Adapter)
        creditFacadeOnly
        withLPTokenApproval
        returns (bool)
    {
        return _remove_diff_liquidity_one_coin(i, leftoverAmount, rateMinRAY);
    }

    /// @notice Serialized adapter parameters
    function serialize() external view override returns (bytes memory serializedData) {
        serializedData =
            abi.encode(creditManager, targetContract, token, lp_token, metapoolBase, nCoins, use256, [token0, token1]);
    }
}
