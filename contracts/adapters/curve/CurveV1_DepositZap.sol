// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {CurveV1AdapterBase} from "./CurveV1_Base.sol";

/// @title Curve V1 DepozitZap adapter
/// @notice Implements logic for interacting with a Curve zap wrapper (to `remove_liquidity_one_coin` from older pools)
contract CurveV1AdapterDeposit is CurveV1AdapterBase {
    AdapterType public constant override _gearboxAdapterType = AdapterType.CURVE_V1_WRAPPER;

    /// @notice Sets allowance for the pool LP token to max before the operation and to 1 after
    modifier withLPTokenApproval() {
        _approveToken(lp_token, type(uint256).max);
        _;
        _approveToken(lp_token, 1);
    }

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _curveDeposit Target Curve DepositZap contract address
    /// @param _lp_token Pool LP token address
    /// @param _nCoins Number of coins in the pool
    constructor(address _creditManager, address _curveDeposit, address _lp_token, uint256 _nCoins)
        CurveV1AdapterBase(_creditManager, _curveDeposit, _lp_token, address(0), _nCoins)
    {}

    /// @inheritdoc CurveV1AdapterBase
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_liquidity_one_coin(uint256 amount, uint256 i, uint256 minAmount)
        public
        virtual
        override
        creditFacadeOnly
        withLPTokenApproval
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _remove_liquidity_one_coin(amount, i, minAmount);
    }

    /// @inheritdoc CurveV1AdapterBase
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_all_liquidity_one_coin(uint256 i, uint256 rateMinRAY)
        public
        virtual
        override
        creditFacadeOnly
        withLPTokenApproval
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _remove_all_liquidity_one_coin(i, rateMinRAY);
    }

    /// @dev Does nothing since this adapter should not be used to add liquidity
    function _getAddLiquidityOneCoinCallData(uint256 i, uint256 amount, uint256 minAmount)
        internal
        view
        override
        returns (bytes memory)
    {}

    /// @dev Does nothing since this adapter should not be used to add liquidity
    function _getCalcAddOneCoinCallData(uint256 i, uint256 amount)
        internal
        view
        override
        returns (bytes memory, bytes memory)
    {}
}
