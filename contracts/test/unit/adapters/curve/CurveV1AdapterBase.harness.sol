// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {CurveV1AdapterBase} from "../../../../adapters/curve/CurveV1_Base.sol";
import {ICurvePool2Assets} from "../../../../integrations/curve/ICurvePool_2.sol";
import {ICurvePool3Assets} from "../../../../integrations/curve/ICurvePool_3.sol";
import {ICurvePool4Assets} from "../../../../integrations/curve/ICurvePool_4.sol";

contract CurveV1AdapterBaseHarness is CurveV1AdapterBase {
    constructor(address _creditManager, address _curvePool, address _lp_token, address _metapoolBase, uint256 _nCoins)
        CurveV1AdapterBase(_creditManager, _curvePool, _lp_token, _metapoolBase, _nCoins)
    {}

    function contractType() public view override returns (bytes32) {
        return (
            nCoins == 2
                ? bytes32("AD_CURVE_V1_2ASSETS")
                : (nCoins == 3 ? bytes32("AD_CURVE_V1_3ASSETS") : bytes32("AD_CURVE_V1_4ASSETS"))
        );
    }

    function _getAddLiquidityOneCoinCallData(uint256 i, uint256 amount, uint256 minAmount)
        internal
        view
        override
        returns (bytes memory callData)
    {
        if (nCoins == 2) {
            uint256[2] memory amounts;
            amounts[i] = amount;
            return abi.encodeCall(ICurvePool2Assets.add_liquidity, (amounts, minAmount));
        } else if (nCoins == 3) {
            uint256[3] memory amounts;
            amounts[i] = amount;
            return abi.encodeCall(ICurvePool3Assets.add_liquidity, (amounts, minAmount));
        } else {
            uint256[4] memory amounts;
            amounts[i] = amount;
            return abi.encodeCall(ICurvePool4Assets.add_liquidity, (amounts, minAmount));
        }
    }

    function _getCalcAddOneCoinCallData(uint256 i, uint256 amount)
        internal
        view
        override
        returns (bytes memory callData, bytes memory callDataAlt)
    {
        if (nCoins == 2) {
            uint256[2] memory amounts;
            amounts[i] = amount;
            return (
                abi.encodeCall(ICurvePool2Assets.calc_token_amount, (amounts, true)),
                abi.encodeWithSignature("calc_token_amount(uint256[2])", amounts)
            );
        } else if (nCoins == 3) {
            uint256[3] memory amounts;
            amounts[i] = amount;
            return (
                abi.encodeCall(ICurvePool3Assets.calc_token_amount, (amounts, true)),
                abi.encodeWithSignature("calc_token_amount(uint256[3])", amounts)
            );
        } else {
            uint256[4] memory amounts;
            amounts[i] = amount;
            return (
                abi.encodeCall(ICurvePool4Assets.calc_token_amount, (amounts, true)),
                abi.encodeWithSignature("calc_token_amount(uint256[4])", amounts)
            );
        }
    }

    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract);
    }
}
