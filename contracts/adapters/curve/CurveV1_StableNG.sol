// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {ICurvePoolStableNG} from "../../integrations/curve/ICurvePool_StableNG.sol";
import {ICurveV1_StableNGAdapter} from "../../interfaces/curve/ICurveV1_StableNGAdapter.sol";
import {CurveV1AdapterBase} from "./CurveV1_Base.sol";

/// @title Curve Stable NG adapter
/// @notice Implements logic allowing to interact with Curve StableNG pools
contract CurveV1AdapterStableNG is CurveV1AdapterBase, ICurveV1_StableNGAdapter {
    bytes32 public constant override contractType = "AD_CURVE_STABLE_NG";

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _curvePool Target Curve pool address
    /// @param _lp_token Pool LP token address
    /// @param _metapoolBase Base pool address (for metapools only) or zero address
    constructor(address _creditManager, address _curvePool, address _lp_token, address _metapoolBase)
        CurveV1AdapterBase(_creditManager, _curvePool, _lp_token, _metapoolBase, ICurvePoolStableNG(_curvePool).N_COINS())
    {}

    /// @notice Add liquidity to the pool
    /// @param amounts Amounts of tokens to add
    /// @dev `min_mint_amount` parameter is ignored because calldata is passed directly to the target contract
    function add_liquidity(uint256[] calldata amounts, uint256) external override creditFacadeOnly returns (bool) {
        uint256 len = amounts.length;
        _add_liquidity(amounts[0] > 1, amounts[1] > 1, len > 2 && amounts[2] > 1, len > 3 && amounts[3] > 1);
        return true;
    }

    /// @dev Returns calldata for adding liquidity in coin `i`
    function _getAddLiquidityOneCoinCallData(uint256 i, uint256 amount, uint256 minAmount)
        internal
        view
        override
        returns (bytes memory)
    {
        uint256[] memory amounts = new uint256[](nCoins);
        amounts[i] = amount;
        return abi.encodeCall(ICurvePoolStableNG.add_liquidity, (amounts, minAmount));
    }

    /// @dev Returns calldata for calculating the result of adding liquidity in coin `i`
    function _getCalcAddOneCoinCallData(uint256 i, uint256 amount)
        internal
        view
        override
        returns (bytes memory, bytes memory)
    {
        uint256[] memory amounts = new uint256[](nCoins);
        amounts[i] = amount;
        return (
            abi.encodeCall(ICurvePoolStableNG.calc_token_amount, (amounts, true)),
            abi.encodeWithSignature("calc_token_amount(uint256[])", amounts)
        );
    }

    /// @notice Remove liquidity from the pool
    /// @dev '_amount' and 'min_amounts' parameters are ignored because calldata is directly passed to the target contract
    function remove_liquidity(uint256, uint256[] calldata) external virtual creditFacadeOnly returns (bool) {
        _execute(msg.data);
        return true;
    }

    /// @notice Withdraw exact amounts of tokens from the pool
    /// @dev `amounts` and `max_burn_amount` parameters are ignored because calldata is directly passed to the target contract
    function remove_liquidity_imbalance(uint256[] calldata, uint256)
        external
        virtual
        override
        creditFacadeOnly
        returns (bool)
    {
        _execute(msg.data);
        return true;
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
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
