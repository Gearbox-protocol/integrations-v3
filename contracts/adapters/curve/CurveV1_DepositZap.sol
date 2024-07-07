// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {CurveV1AdapterBase} from "./CurveV1_Base.sol";

/// @title Curve V1 DepozitZap adapter
/// @notice Implements logic for interacting with a Curve zap wrapper (to `remove_liquidity_one_coin` from older pools)
contract CurveV1AdapterDeposit is CurveV1AdapterBase {
    bytes32 public constant override contractType = "AD_CURVE_V1_WRAPPER";

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
        returns (bool)
    {
        _remove_liquidity_one_coin(amount, i, minAmount);
        return true;
    }

    /// @inheritdoc CurveV1AdapterBase
    /// @dev Unlike other adapters, approves the LP token to the target
    function remove_liquidity_one_coin(uint256 amount, int128 i, uint256 minAmount)
        public
        virtual
        override
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
        virtual
        override
        creditFacadeOnly
        withLPTokenApproval
        returns (bool)
    {
        return _remove_diff_liquidity_one_coin(i, leftoverAmount, rateMinRAY);
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

    /// @notice Returns all adapter parameters serialized into a bytes array,
    ///         as well as adapter type and version, to properly deserialize
    function serialize() external view override returns (bytes memory serializedData) {
        serializedData = abi.encode(
            creditManager,
            targetContract,
            token,
            lp_token,
            metapoolBase,
            nCoins,
            use256,
            [token0, token1, token2, token3],
            [underlying0, underlying1, underlying2, underlying3]
        );
    }
}
