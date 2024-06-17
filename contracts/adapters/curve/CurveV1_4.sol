// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {ICurvePool4Assets, N_COINS} from "../../integrations/curve/ICurvePool_4.sol";
import {ICurveV1_4AssetsAdapter} from "../../interfaces/curve/ICurveV1_4AssetsAdapter.sol";
import {CurveV1AdapterBase} from "./CurveV1_Base.sol";

/// @title Curve V1 4 assets adapter
/// @notice Implements logic allowing to interact with Curve pools with 4 assets
contract CurveV1Adapter4Assets is CurveV1AdapterBase, ICurveV1_4AssetsAdapter {
    function _gearboxAdapterType() public pure virtual override returns (AdapterType) {
        return AdapterType.CURVE_V1_4ASSETS;
    }

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _curvePool Target Curve pool address
    /// @param _lp_token Pool LP token address
    /// @param _metapoolBase Base pool address (for metapools only) or zero address
    constructor(address _creditManager, address _curvePool, address _lp_token, address _metapoolBase)
        CurveV1AdapterBase(_creditManager, _curvePool, _lp_token, _metapoolBase, N_COINS)
    {}

    /// @notice Add liquidity to the pool
    /// @param amounts Amounts of tokens to add
    /// @dev `min_mint_amount` parameter is ignored because calldata is passed directly to the target contract
    function add_liquidity(uint256[N_COINS] calldata amounts, uint256)
        external
        override
        creditFacadeOnly // U:[CRV4-1]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) =
            _add_liquidity(amounts[0] > 1, amounts[1] > 1, amounts[2] > 1, amounts[3] > 1); // U:[CRV4-2]
    }

    /// @dev Returns calldata for adding liquidity in coin `i`
    function _getAddLiquidityOneCoinCallData(uint256 i, uint256 amount, uint256 minAmount)
        internal
        pure
        override
        returns (bytes memory)
    {
        uint256[4] memory amounts;
        amounts[i] = amount;
        return abi.encodeCall(ICurvePool4Assets.add_liquidity, (amounts, minAmount));
    }

    /// @dev Returns calldata for calculating the result of adding liquidity in coin `i`
    function _getCalcAddOneCoinCallData(uint256 i, uint256 amount)
        internal
        pure
        override
        returns (bytes memory, bytes memory)
    {
        uint256[4] memory amounts;
        amounts[i] = amount;
        return (
            abi.encodeCall(ICurvePool4Assets.calc_token_amount, (amounts, true)),
            abi.encodeWithSignature("calc_token_amount(uint256[4])", amounts)
        );
    }

    /// @notice Remove liquidity from the pool
    /// @dev '_amount' and 'min_amounts' parameters are ignored because calldata is directly passed to the target contract
    function remove_liquidity(uint256, uint256[N_COINS] calldata)
        external
        virtual
        creditFacadeOnly // U:[CRV4-1]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _remove_liquidity(); // U:[CRV4-3]
    }

    /// @notice Withdraw exact amounts of tokens from the pool
    /// @param amounts Amounts of tokens to withdraw
    /// @dev `max_burn_amount` parameter is ignored because calldata is directly passed to the target contract
    function remove_liquidity_imbalance(uint256[N_COINS] calldata amounts, uint256)
        external
        virtual
        override
        creditFacadeOnly // U:[CRV4-1]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) =
            _remove_liquidity_imbalance(amounts[0] > 1, amounts[1] > 1, amounts[2] > 1, amounts[3] > 1); // U:[CRV4-4]
    }

    /// @notice Returns all adapter parameters serialized into a bytes array,
    ///         as well as adapter type and version, to properly deserialize
    function serialize() external view override returns (AdapterType, uint16, bytes[] memory) {
        bytes[] memory serializedData = new bytes[](23);
        serializedData[0] = abi.encode(creditManager);
        serializedData[1] = abi.encode(targetContract);
        serializedData[2] = abi.encode(token);
        serializedData[3] = abi.encode(lp_token);
        serializedData[4] = abi.encode(lpTokenMask);
        serializedData[5] = abi.encode(metapoolBase);
        serializedData[6] = abi.encode(use256);
        serializedData[7] = abi.encode(token0);
        serializedData[8] = abi.encode(token1);
        serializedData[9] = abi.encode(token2);
        serializedData[10] = abi.encode(token3);
        serializedData[11] = abi.encode(token0Mask);
        serializedData[12] = abi.encode(token1Mask);
        serializedData[13] = abi.encode(token2Mask);
        serializedData[14] = abi.encode(token3Mask);
        serializedData[15] = abi.encode(underlying0);
        serializedData[16] = abi.encode(underlying1);
        serializedData[17] = abi.encode(underlying2);
        serializedData[18] = abi.encode(underlying3);
        serializedData[19] = abi.encode(underlying0Mask);
        serializedData[20] = abi.encode(underlying1Mask);
        serializedData[21] = abi.encode(underlying2Mask);
        serializedData[22] = abi.encode(underlying3Mask);
        return (_gearboxAdapterType(), _gearboxAdapterVersion, serializedData);
    }
}
