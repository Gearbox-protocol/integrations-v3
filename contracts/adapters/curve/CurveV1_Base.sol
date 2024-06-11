// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {BitMask} from "@gearbox-protocol/core-v3/contracts/libraries/BitMask.sol";
import {IncorrectParameterException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {ICurvePool} from "../../integrations/curve/ICurvePool.sol";
import {ICurveV1Adapter} from "../../interfaces/curve/ICurveV1Adapter.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";

/// @title Curve adapter base
/// @notice Implements logic allowing credit accounts to interact with Curve pools with arbitrary number of coins,
///         supporting stable/crypto plain/meta/lending pools of different versions
abstract contract CurveV1AdapterBase is AbstractAdapter, ICurveV1Adapter {
    using BitMask for uint256;

    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice Pool LP token address (added for backward compatibility)
    address public immutable override token;

    /// @notice Pool LP token address
    address public immutable override lp_token;

    /// @notice Collateral token mask of pool LP token in the credit manager
    uint256 public immutable override lpTokenMask;

    /// @notice Base pool address (for metapools only)
    address public immutable override metapoolBase;

    /// @notice Number of coins in the pool
    uint256 public immutable override nCoins;

    /// @notice Whether pool is cryptoswap or stableswap
    bool public immutable override use256;

    address public immutable override token0;
    address public immutable override token1;
    address public immutable override token2;
    address public immutable override token3;

    uint256 public immutable override token0Mask;
    uint256 public immutable override token1Mask;
    uint256 public immutable override token2Mask;
    uint256 public immutable override token3Mask;

    address public immutable override underlying0;
    address public immutable override underlying1;
    address public immutable override underlying2;
    address public immutable override underlying3;

    uint256 public immutable override underlying0Mask;
    uint256 public immutable override underlying1Mask;
    uint256 public immutable override underlying2Mask;
    uint256 public immutable override underlying3Mask;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _curvePool Target Curve pool address
    /// @param _lp_token Pool LP token address
    /// @param _metapoolBase Metapool's base pool address (must have 2 or 3 coins) or zero address
    /// @param _nCoins Number of coins in the pool
    constructor(address _creditManager, address _curvePool, address _lp_token, address _metapoolBase, uint256 _nCoins)
        AbstractAdapter(_creditManager, _curvePool) // U:[CRVB-1]
        nonZeroAddress(_lp_token) // U:[CRVB-1]
    {
        lpTokenMask = _getMaskOrRevert(_lp_token); // U:[CRVB-1]

        token = _lp_token; // U:[CRVB-1]
        lp_token = _lp_token; // U:[CRVB-1]
        metapoolBase = _metapoolBase; // U:[CRVB-1]
        nCoins = _nCoins; // U:[CRVB-1]
        use256 = _use256();

        address[4] memory tokens;
        uint256[4] memory tokenMasks;
        unchecked {
            for (uint256 i; i < nCoins; ++i) {
                tokens[i] = _getCoin(_curvePool, i); // U:[CRVB-1]
                if (tokens[i] == address(0)) revert IncorrectParameterException(); // U:[CRVB-1]
                tokenMasks[i] = _getMaskOrRevert(tokens[i]); // U:[CRVB-1]
            }
        }

        token0 = tokens[0];
        token1 = tokens[1];
        token2 = tokens[2];
        token3 = tokens[3];

        token0Mask = tokenMasks[0];
        token1Mask = tokenMasks[1];
        token2Mask = tokenMasks[2];
        token3Mask = tokenMasks[3];

        // underlying tokens (only relevant for meta and lending pools)
        address[4] memory underlyings;
        uint256[4] memory underlyingMasks;
        unchecked {
            for (uint256 i; i < 4; ++i) {
                if (_metapoolBase != address(0)) {
                    underlyings[i] = i == 0 ? token0 : _getCoin(_metapoolBase, i - 1); // U:[CRVB-1]
                } else {
                    // some pools are proxy contracts and return empty data when there is no function with given signature,
                    // which later results in revert when trying to decode the result, so low-level call is used instead
                    (bool success, bytes memory returnData) = _callWithAlternative(
                        abi.encodeWithSignature("underlying_coins(uint256)", i),
                        abi.encodeWithSignature("underlying_coins(int128)", i)
                    ); // U:[CRVB-1]
                    if (success && returnData.length > 0) underlyings[i] = abi.decode(returnData, (address));
                    else break;
                }

                if (underlyings[i] != address(0)) underlyingMasks[i] = _getMaskOrRevert(underlyings[i]); // U:[CRVB-1]
            }
        }

        underlying0 = underlyings[0];
        underlying1 = underlyings[1];
        underlying2 = underlyings[2];
        underlying3 = underlyings[3];

        underlying0Mask = underlyingMasks[0];
        underlying1Mask = underlyingMasks[1];
        underlying2Mask = underlyingMasks[2];
        underlying3Mask = underlyingMasks[3];
    }

    // -------- //
    // EXCHANGE //
    // -------- //

    /// @notice Exchanges one pool asset to another
    /// @param i Index of the asset to spend
    /// @param j Index of the asset to receive
    /// @param dx Amount of asset i to spend
    /// @param min_dy Minimum amount of asset j to receive
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy)
        external
        override
        creditFacadeOnly // U:[CRVB-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        return _exchange(i, j, dx, min_dy); // U:[CRVB-3]
    }

    /// @dev Same as the previous one but accepts coin indexes as `int128`
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy)
        external
        override
        creditFacadeOnly // U:[CRVB-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        return _exchange(_toU256(i), _toU256(j), dx, min_dy); // U:[CRVB-3]
    }

    /// @dev Implementation of both versions of `exchange`
    function _exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _exchange_impl(i, j, _getExchangeCallData(i, j, dx, min_dy), false); // U:[CRVB-3]
    }

    /// @notice Exchanges the entire balance of one pool asset to another, except the specified amount
    /// @param i Index of the asset to spend
    /// @param j Index of the asset to receive
    /// @param leftoverAmount Amount of input asset to keep on the account
    /// @param rateMinRAY Minimum exchange rate between assets i and j, scaled by 1e27
    function exchange_diff(uint256 i, uint256 j, uint256 leftoverAmount, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly // U:[CRVB-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[CRVB-4]

        address tokenIn = _get_token(i); // U:[CRVB-4]
        uint256 dx = IERC20(tokenIn).balanceOf(creditAccount); // U:[CRVB-4]
        if (dx <= leftoverAmount) return (0, 0);

        unchecked {
            dx -= leftoverAmount; // U:[CRVB-4]
        }
        uint256 min_dy = (dx * rateMinRAY) / RAY; // U:[CRVB-4]
        (tokensToEnable, tokensToDisable) =
            _exchange_impl(i, j, _getExchangeCallData(i, j, dx, min_dy), leftoverAmount <= 1); // U:[CRVB-4]
    }

    /// @dev Internal implementation of `exchange` and `exchange_diff`
    ///      - passes calldata to the target contract
    ///      - sets max approval for the input token before the call and resets it to 1 after
    ///      - enables output asset after the call
    ///      - disables input asset only when exchanging the entire balance
    function _exchange_impl(uint256 i, uint256 j, bytes memory callData, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(_get_token(i), type(uint256).max); // U:[CRVB-3,4]
        _execute(callData); // U:[CRVB-3,4]
        _approveToken(_get_token(i), 1); // U:[CRVB-3,4]
        (tokensToEnable, tokensToDisable) = (_get_token_mask(j), disableTokenIn ? _get_token_mask(i) : 0); // U:[CRVB-3,4]
    }

    /// @dev Returns calldata for `exchange` and `exchange_diff` calls
    function _getExchangeCallData(uint256 i, uint256 j, uint256 dx, uint256 min_dy)
        internal
        view
        returns (bytes memory)
    {
        return use256
            ? abi.encodeWithSignature("exchange(uint256,uint256,uint256,uint256)", i, j, dx, min_dy)
            : abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)", i, j, dx, min_dy); // U:[CRVB-3,4]
    }

    /// @notice Exchanges one pool's underlying asset to another
    /// @param i Index of the underlying asset to spend
    /// @param j Index of the underlying asset to receive
    /// @param dx Amount of underlying asset i to spend
    /// @param min_dy Minimum amount of underlying asset j to receive
    function exchange_underlying(uint256 i, uint256 j, uint256 dx, uint256 min_dy)
        external
        override
        creditFacadeOnly // U:[CRVB-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        return _exchange_underlying(i, j, dx, min_dy); // U:[CRVB-5]
    }

    /// @dev Same as the previous one but accepts coin indexes as `int128`
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy)
        external
        override
        creditFacadeOnly // U:[CRVB-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        return _exchange_underlying(_toU256(i), _toU256(j), dx, min_dy); // U:[CRVB-5]
    }

    /// @dev Implementation of both versions of `exchange_underlying`
    function _exchange_underlying(uint256 i, uint256 j, uint256 dx, uint256 min_dy)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) =
            _exchange_underlying_impl(i, j, _getExchangeUnderlyingCallData(i, j, dx, min_dy), false); // U:[CRVB-5]
    }

    /// @notice Exchanges the entire balance of one pool's underlying asset to another, except the specified amount
    /// @param i Index of the underlying asset to spend
    /// @param j Index of the underlying asset to receive
    /// @param rateMinRAY Minimum exchange rate between underlying assets i and j, scaled by 1e27
    function exchange_diff_underlying(uint256 i, uint256 j, uint256 leftoverAmount, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly // U:[CRVB-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[CRVB-6]

        address tokenIn = _get_underlying(i); // U:[CRVB-6]
        uint256 dx = IERC20(tokenIn).balanceOf(creditAccount); // U:[CRVB-6]
        if (dx <= leftoverAmount) return (0, 0);

        unchecked {
            dx -= leftoverAmount; // U:[CRVB-6]
        }
        uint256 min_dy = (dx * rateMinRAY) / RAY; // U:[CRVB-6]
        (tokensToEnable, tokensToDisable) =
            _exchange_underlying_impl(i, j, _getExchangeUnderlyingCallData(i, j, dx, min_dy), leftoverAmount <= 1); // U:[CRVB-6]
    }

    /// @dev Internal implementation of `exchange_underlying` and `exchange_diff_underlying`
    ///      - passes calldata to the target contract
    ///      - sets max approval for the input token before the call and resets it to 1 after
    ///      - enables output asset after the call
    ///      - disables input asset only when exchanging the entire balance
    function _exchange_underlying_impl(uint256 i, uint256 j, bytes memory callData, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(_get_underlying(i), type(uint256).max); // U:[CRVB-5,6]
        _execute(callData); // U:[CRVB-5,6]
        _approveToken(_get_underlying(i), 1); // U:[CRVB-5,6]
        (tokensToEnable, tokensToDisable) = (_get_underlying_mask(j), disableTokenIn ? _get_underlying_mask(i) : 0); // U:[CRVB-5,6]
    }

    /// @dev Returns calldata for `exchange_underlying` and `exchange_diff_underlying` calls
    function _getExchangeUnderlyingCallData(uint256 i, uint256 j, uint256 dx, uint256 min_dy)
        internal
        view
        returns (bytes memory)
    {
        return use256
            ? abi.encodeWithSignature("exchange_underlying(uint256,uint256,uint256,uint256)", i, j, dx, min_dy)
            : abi.encodeWithSignature("exchange_underlying(int128,int128,uint256,uint256)", i, j, dx, min_dy); // U:[CRVB-5,6]
    }

    // ------------- //
    // ADD LIQUIDITY //
    // ------------- //

    /// @dev Internal implementation of `add_liquidity`
    ///      - passes calldata to the target contract
    ///      - sets max approvals for the specified tokens before the call and resets them to 1 after
    ///      - enables LP token
    function _add_liquidity(bool t0Approve, bool t1Approve, bool t2Approve, bool t3Approve)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveTokens(t0Approve, t1Approve, t2Approve, t3Approve, type(uint256).max); // U:[CRV2-2, CRV3-2, CRV4-2]
        _execute(msg.data); // U:[CRV2-2, CRV3-2, CRV4-2]
        _approveTokens(t0Approve, t1Approve, t2Approve, t3Approve, 1); // U:[CRV2-2, CRV3-2, CRV4-2]
        (tokensToEnable, tokensToDisable) = (lpTokenMask, 0); // U:[CRV2-2, CRV3-2, CRV4-2]
    }

    /// @notice Adds given amount of asset as liquidity to the pool
    /// @param amount Amount to deposit
    /// @param i Index of the asset to deposit
    /// @param minAmount Minimum amount of LP tokens to receive
    function add_liquidity_one_coin(uint256 amount, uint256 i, uint256 minAmount)
        external
        override
        creditFacadeOnly // U:[CRVB-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) =
            _add_liquidity_one_coin_impl(i, _getAddLiquidityOneCoinCallData(i, amount, minAmount), false); // U:[CRVB-7]
    }

    /// @notice Adds the entire balance of asset as liquidity to the pool, except the specified amount
    /// @param leftoverAmount Amount of underlying to keep on the account
    /// @param i Index of the asset to deposit
    /// @param rateMinRAY Minimum exchange rate between deposited asset and LP token, scaled by 1e27
    function add_diff_liquidity_one_coin(uint256 leftoverAmount, uint256 i, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly // U:[CRVB-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[CRVB-8]

        address tokenIn = _get_token(i); // U:[CRVB-8]
        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount); // U:[CRVB-8]
        if (amount <= leftoverAmount) return (0, 0);

        unchecked {
            amount -= leftoverAmount; // U:[CRVB-8]
        }
        uint256 minAmount = (amount * rateMinRAY) / RAY; // U:[CRVB-8]
        (tokensToEnable, tokensToDisable) =
            _add_liquidity_one_coin_impl(i, _getAddLiquidityOneCoinCallData(i, amount, minAmount), leftoverAmount <= 1); // U:[CRVB-8]
    }

    /// @dev Internal implementation of `add_liquidity_one_coin' and `add_diff_liquidity_one_coin`
    ///      - passes calldata to the target contract
    ///      - sets max approval for the input token before the call and resets it to 1 after
    ///      - enables LP token
    ///      - disables input token only when adding the entire balance
    function _add_liquidity_one_coin_impl(uint256 i, bytes memory callData, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(_get_token(i), type(uint256).max); // U:[CRVB-7,8]
        _execute(callData); // U:[CRVB-7,8]
        _approveToken(_get_token(i), 1); // U:[CRVB-7,8]
        (tokensToEnable, tokensToDisable) = (lpTokenMask, disableTokenIn ? _get_token_mask(i) : 0); // U:[CRVB-7,8]
    }

    /// @notice Returns the amount of LP token received for adding a single asset to the pool
    /// @param amount Amount to deposit
    /// @param i Index of the asset to deposit
    function calc_add_one_coin(uint256 amount, uint256 i) external view override returns (uint256) {
        // some pools omit the second argument of `calc_token_amount` function, so
        // a call with alternative signature is made in case the first one fails
        (bytes memory callData, bytes memory callDataAlt) = _getCalcAddOneCoinCallData(i, amount);
        (bool success, bytes memory returnData) = _callWithAlternative(callData, callDataAlt);
        if (success && returnData.length > 0) {
            return abi.decode(returnData, (uint256));
        } else {
            revert("calc_token_amount reverted");
        }
    }

    /// @dev Returns calldata for adding liquidity in coin `i`, must be overriden in derived adapters
    function _getAddLiquidityOneCoinCallData(uint256 i, uint256 amount, uint256 minAmount)
        internal
        view
        virtual
        returns (bytes memory callData);

    /// @dev Returns calldata for calculating the result of adding liquidity in coin `i`,
    ///      must be overriden in derived adapters
    function _getCalcAddOneCoinCallData(uint256 i, uint256 amount)
        internal
        view
        virtual
        returns (bytes memory callData, bytes memory callDataAlt);

    // ---------------- //
    // REMOVE LIQUIDITY //
    // ---------------- //

    /// @dev Internal implementation of `remove_liquidity`
    ///      - passes calldata to the target contract
    ///      - enables all pool tokens
    function _remove_liquidity() internal returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        _execute(msg.data); // U:[CRV2-3, CRV3-3, CRV4-3]
        (tokensToEnable, tokensToDisable) = (token0Mask | token1Mask | token2Mask | token3Mask, 0); // U:[CRV2-3, CRV3-3, CRV4-3]
    }

    /// @dev Internal implementation of `remove_liquidity_imbalance`
    ///      - passes calldata to the target contract
    ///      - enables specified pool tokens
    function _remove_liquidity_imbalance(bool t0Enable, bool t1Enable, bool t2Enable, bool t3Enable)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(msg.data); // U:[CRV2-4, CRV3-4, CRV4-4]

        if (t0Enable) tokensToEnable = tokensToEnable.enable(token0Mask); // U:[CRV2-4, CRV3-4, CRV4-4]
        if (t1Enable) tokensToEnable = tokensToEnable.enable(token1Mask); // U:[CRV2-4, CRV3-4, CRV4-4]
        if (t2Enable) tokensToEnable = tokensToEnable.enable(token2Mask); // U:[CRV3-4, CRV4-4]
        if (t3Enable) tokensToEnable = tokensToEnable.enable(token3Mask); // U:[CRV4-4]
        tokensToDisable = 0; // U:[CRV2-4, CRV3-4, CRV4-4]
    }

    /// @notice Removes liquidity from the pool in a specified asset
    /// @param amount Amount of liquidity to remove
    /// @param i Index of the asset to withdraw
    /// @param minAmount Minimum amount of asset to receive
    function remove_liquidity_one_coin(uint256 amount, uint256 i, uint256 minAmount)
        external
        virtual
        override
        creditFacadeOnly // U:[CRVB-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _remove_liquidity_one_coin(amount, i, minAmount); // U:[CRVB-9]
    }

    /// @dev Same as the previous one but accepts coin indexes as `int128`
    function remove_liquidity_one_coin(uint256 amount, int128 i, uint256 minAmount)
        external
        virtual
        override
        creditFacadeOnly // U:[CRVB-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _remove_liquidity_one_coin(amount, _toU256(i), minAmount); // U:[CRVB-9]
    }

    /// @dev Implementation of both versions of `remove_liquidity_one_coin`
    function _remove_liquidity_one_coin(uint256 amount, uint256 i, uint256 minAmount)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) =
            _remove_liquidity_one_coin_impl(i, _getRemoveLiquidityOneCoinCallData(i, amount, minAmount), false); // U:[CRVB-9]
    }

    /// @notice Removes all liquidity from the pool, except the specified amount, in a specified asset
    /// @param leftoverAmount Amount of Curve LP to keep on the account
    /// @param i Index of the asset to withdraw
    /// @param rateMinRAY Minimum exchange rate between LP token and received token, scaled by 1e27
    function remove_diff_liquidity_one_coin(uint256 leftoverAmount, uint256 i, uint256 rateMinRAY)
        external
        virtual
        override
        creditFacadeOnly // U:[CRVB-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        return _remove_diff_liquidity_one_coin(i, leftoverAmount, rateMinRAY); // U:[CRVB-10]
    }

    /// @dev Implementation of `remove_diff_liquidity_one_coin`
    function _remove_diff_liquidity_one_coin(uint256 i, uint256 leftoverAmount, uint256 rateMinRAY)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[CRVB-10]

        uint256 amount = IERC20(lp_token).balanceOf(creditAccount); // U:[CRVB-10]
        if (amount <= leftoverAmount) return (0, 0);

        unchecked {
            amount -= leftoverAmount; // U:[CRVB-10]
        }
        uint256 minAmount = (amount * rateMinRAY) / RAY; // U:[CRVB-10]
        (tokensToEnable, tokensToDisable) = _remove_liquidity_one_coin_impl(
            i, _getRemoveLiquidityOneCoinCallData(i, amount, minAmount), leftoverAmount <= 1
        ); // U:[CRVB-10]
    }

    /// @dev Internal implementation of `remove_liquidity_one_coin` and `remove_diff_liquidity_one_coin`
    ///      - passes calldata to the targe contract
    ///      - enables received asset
    ///      - disables LP token only when removing all liquidity
    function _remove_liquidity_one_coin_impl(uint256 i, bytes memory callData, bool disableLP)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(callData);
        (tokensToEnable, tokensToDisable) = (_get_token_mask(i), disableLP ? lpTokenMask : 0); // U:[CRVB-9,10]
    }

    /// @dev Returns calldata for `remove_liquidity_one_coin` and `remove_diff_liquidity_one_coin` calls
    function _getRemoveLiquidityOneCoinCallData(uint256 i, uint256 amount, uint256 minAmount)
        internal
        view
        returns (bytes memory)
    {
        return use256
            ? abi.encodeWithSignature("remove_liquidity_one_coin(uint256,uint256,uint256)", amount, i, minAmount)
            : abi.encodeWithSignature("remove_liquidity_one_coin(uint256,int128,uint256)", amount, i, minAmount); // U:[CRVB-9,10]
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Returns true if pool is a cryptoswap pool, which is determined by whether it implements `mid_fee`
    function _use256() internal view returns (bool result) {
        try ICurvePool(targetContract).mid_fee() returns (uint256) {
            result = true;
        } catch {
            result = false;
        }
    }

    /// @dev Returns `i`-th coin of the `pool`, tries both signatures
    function _getCoin(address pool, uint256 i) internal view returns (address coin) {
        try ICurvePool(pool).coins(i) returns (address addr) {
            coin = addr;
        } catch {
            try ICurvePool(pool).coins(int128(int256(i))) returns (address addr) {
                coin = addr;
            } catch {}
        }
    }

    /// @dev Performs a low-level call to the target contract with provided calldata, and, should it fail,
    ///      makes a second call with alternative calldata
    function _callWithAlternative(bytes memory callData, bytes memory callDataAlt)
        internal
        view
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = targetContract.staticcall(callData);
        if (!success || returnData.length == 0) {
            (success, returnData) = targetContract.staticcall(callDataAlt);
        }
    }

    /// @dev Returns token `i`'s address
    function _get_token(uint256 i) internal view returns (address addr) {
        if (i == 0) return token0;
        if (i == 1) return token1;
        if (i == 2) return token2;
        if (i == 3) return token3;
    }

    /// @dev Returns underlying `i`'s address
    function _get_underlying(uint256 i) internal view returns (address addr) {
        if (i == 0) return underlying0;
        if (i == 1) return underlying1;
        if (i == 2) return underlying2;
        if (i == 3) return underlying3;
    }

    /// @dev Returns token `i`'s mask
    function _get_token_mask(uint256 i) internal view returns (uint256 mask) {
        if (i == 0) return token0Mask;
        if (i == 1) return token1Mask;
        if (i == 2) return token2Mask;
        if (i == 3) return token3Mask;
    }

    /// @dev Returns underlying `i`'s mask
    function _get_underlying_mask(uint256 i) internal view returns (uint256 mask) {
        if (i == 0) return underlying0Mask;
        if (i == 1) return underlying1Mask;
        if (i == 2) return underlying2Mask;
        if (i == 3) return underlying3Mask;
    }

    /// @dev Sets target contract's approval for specified tokens to `amount`
    function _approveTokens(bool t0Approve, bool t1Approve, bool t2Approve, bool t3Approve, uint256 amount) internal {
        if (t0Approve) _approveToken(token0, amount);
        if (t1Approve) _approveToken(token1, amount);
        if (t2Approve) _approveToken(token2, amount);
        if (t3Approve) _approveToken(token3, amount);
    }

    /// @dev Returns `int128`-typed number as `uint256`
    function _toU256(int128 i) internal pure returns (uint256) {
        return uint256(int256(i));
    }
}
