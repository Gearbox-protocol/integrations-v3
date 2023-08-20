// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {BitMask} from "@gearbox-protocol/core-v3/contracts/libraries/BitMask.sol";
import {ZeroAddressException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {ICurvePool} from "../../integrations/curve/ICurvePool.sol";
import {ICurvePool2Assets} from "../../integrations/curve/ICurvePool_2.sol";
import {ICurvePool3Assets} from "../../integrations/curve/ICurvePool_3.sol";
import {ICurvePool4Assets} from "../../integrations/curve/ICurvePool_4.sol";

import {ICurveV1Adapter} from "../../interfaces/curve/ICurveV1Adapter.sol";

uint256 constant ZERO = 0;

/// @title Curve V1 adapter base
/// @notice Implements logic allowing to interact with all Curve pools, regardless of number of coins
abstract contract CurveV1AdapterBase is AbstractAdapter, ICurveV1Adapter {
    using SafeCast for uint256;
    using SafeCast for int256;
    using BitMask for uint256;

    uint16 public constant override _gearboxAdapterVersion = 2;

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

    /// @notice Whether to use uint256 for token indexes in write functions
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
    /// @param _metapoolBase Base pool address (for metapools only) or zero address
    /// @param _nCoins Number of coins in the pool
    constructor(address _creditManager, address _curvePool, address _lp_token, address _metapoolBase, uint256 _nCoins)
        AbstractAdapter(_creditManager, _curvePool)
        nonZeroAddress(_lp_token) // F: [ACV1-1]
    {
        lpTokenMask = _getMaskOrRevert(_lp_token); // F: [ACV1-2]

        token = _lp_token; // F: [ACV1-2]
        lp_token = _lp_token; // F: [ACV1-2]
        metapoolBase = _metapoolBase; // F: [ACV1-2]
        nCoins = _nCoins; // F: [ACV1-2]

        {
            // Only Curve v2 pools implement `mid_fee()`, so it can be used to determine
            // whether to use function signatures with `int128` or `uint256` indexes
            bool _use256;
            try ICurvePool(targetContract).mid_fee() returns (uint256) {
                _use256 = true;
            } catch {
                _use256 = false;
            }

            use256 = _use256;
        }

        address[4] memory tokens;
        uint256[4] memory tokenMasks;
        for (uint256 i = 0; i < nCoins;) {
            address currentCoin;
            try ICurvePool(targetContract).coins(i) returns (address tokenAddress) {
                currentCoin = tokenAddress;
            } catch {
                try ICurvePool(targetContract).coins(i.toInt256().toInt128()) returns (address tokenAddress) {
                    currentCoin = tokenAddress;
                } catch {}
            }

            if (currentCoin == address(0)) revert ZeroAddressException(); // F: [ACV1-1]

            tokens[i] = currentCoin;
            tokenMasks[i] = _getMaskOrRevert(currentCoin);

            unchecked {
                ++i;
            }
        }

        token0 = tokens[0]; // F: [ACV1-2]
        token1 = tokens[1]; // F: [ACV1-2]
        token2 = tokens[2]; // F: [ACV1-2]
        token3 = tokens[3]; // F: [ACV1-2]

        token0Mask = tokenMasks[0]; // F: [ACV1-2]
        token1Mask = tokenMasks[1]; // F: [ACV1-2]
        token2Mask = tokenMasks[2]; // F: [ACV1-2]
        token3Mask = tokenMasks[3]; // F: [ACV1-2]

        tokens = [address(0), address(0), address(0), address(0)];
        tokenMasks = [ZERO, ZERO, ZERO, ZERO];

        for (uint256 i = 0; i < 4;) {
            address currentCoin;
            uint256 currentMask;

            if (metapoolBase != address(0)) {
                if (i == 0) {
                    currentCoin = token0;
                } else {
                    try ICurvePool(metapoolBase).coins(i - 1) returns (address tokenAddress) {
                        currentCoin = tokenAddress;
                    } catch {}
                }
            } else {
                // Curve Crypto factory pools make a proxy call to implementation and send back raw received data,
                // which means calls with unknown signatures can be successful while returning no data.
                // This necessitates a low-level call.

                bool success;
                bytes memory returndata;

                (success, returndata) = targetContract.call(abi.encodeWithSignature("underlying_coins(uint256)", i));

                if (!success || returndata.length == 0) {
                    (success, returndata) = targetContract.call(
                        abi.encodeWithSignature("underlying_coins(int128)", i.toInt256().toInt128())
                    );
                }

                if (success && returndata.length > 0) {
                    currentCoin = abi.decode(returndata, (address));
                }
            }

            if (currentCoin != address(0)) {
                currentMask = _getMaskOrRevert(currentCoin); // F: [ACV1-1]
            }

            tokens[i] = currentCoin;
            tokenMasks[i] = currentMask;

            unchecked {
                ++i;
            }
        }

        underlying0 = tokens[0]; // F: [ACV1-2]
        underlying1 = tokens[1]; // F: [ACV1-2]
        underlying2 = tokens[2]; // F: [ACV1-2]
        underlying3 = tokens[3]; // F: [ACV1-2]

        underlying0Mask = tokenMasks[0]; // F: [ACV1-2]
        underlying1Mask = tokenMasks[1]; // F: [ACV1-2]
        underlying2Mask = tokenMasks[2]; // F: [ACV1-2]
        underlying3Mask = tokenMasks[3]; // F: [ACV1-2]
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
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) =
            _exchange_impl(i, j, _getExchangeCallData(i, j, dx, min_dy, false), false, false); // F: [ACV1-4]
    }

    /// @notice Exchanges the entire balance of one pool asset to another, disables input asset
    /// @param i Index of the asset to spend
    /// @param j Index of the asset to receive
    /// @param rateMinRAY Minimum exchange rate between assets i and j, scaled by 1e27
    function exchange_all(uint256 i, uint256 j, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // F: [ACV1-3]

        address tokenIn = _get_token(i, false); // F: [ACV1-5]
        uint256 dx = IERC20(tokenIn).balanceOf(creditAccount); // F: [ACV1-5]
        if (dx <= 1) return (0, 0);

        unchecked {
            dx--;
        }
        uint256 min_dy = (dx * rateMinRAY) / RAY; // F: [ACV1-5]
        (tokensToEnable, tokensToDisable) =
            _exchange_impl(i, j, _getExchangeCallData(i, j, dx, min_dy, false), false, true); // F: [ACV1-5]
    }

    /// @notice Exchanges one pool's underlying asset to another
    /// @param i Index of the underlying asset to spend
    /// @param j Index of the underlying asset to receive
    /// @param dx Amount of underlying asset i to spend
    /// @param min_dy Minimum amount of underlying asset j to receive
    function exchange_underlying(uint256 i, uint256 j, uint256 dx, uint256 min_dy)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) =
            _exchange_impl(i, j, _getExchangeCallData(i, j, dx, min_dy, true), true, false); // F: [ACV1-6]
    }

    /// @notice Exchanges the entire balance of one pool's underlying asset to another, disables input asset
    /// @param i Index of the underlying asset to spend
    /// @param j Index of the underlying asset to receive
    /// @param rateMinRAY Minimum exchange rate between underlying assets i and j, scaled by 1e27
    function exchange_all_underlying(uint256 i, uint256 j, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); //F: [ACV1-3]

        address tokenIn = _get_token(i, true); // F: [ACV1-7]
        uint256 dx = IERC20(tokenIn).balanceOf(creditAccount); // F: [ACV1-7]
        if (dx <= 1) return (0, 0);

        unchecked {
            dx--; // F: [ACV1-7]
        }
        uint256 min_dy = (dx * rateMinRAY) / RAY; // F: [ACV1-7]
        (tokensToEnable, tokensToDisable) =
            _exchange_impl(i, j, _getExchangeCallData(i, j, dx, min_dy, true), true, true); // F: [ACV1-7]
    }

    /// @dev Internal implementation of exchange functions
    ///      - passes calldata to the target contract
    ///      - sets max approval for the input token before the call and resets it to 1 after
    ///      - enables output asset after the call
    ///      - disables input asset only when exchanging the entire balance
    function _exchange_impl(uint256 i, uint256 j, bytes memory callData, bool underlying, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approve_token(i, underlying, type(uint256).max);
        _execute(callData);
        _approve_token(i, underlying, 1);
        (tokensToEnable, tokensToDisable) =
            (_get_token_mask(j, underlying), disableTokenIn ? _get_token_mask(i, underlying) : 0);
    }

    /// @dev Returns calldata for `ICurvePool.exchange` and `ICurvePool.exchange_underlying` calls
    function _getExchangeCallData(uint256 i, uint256 j, uint256 dx, uint256 min_dy, bool underlying)
        internal
        view
        returns (bytes memory)
    {
        if (use256) {
            return underlying
                ? abi.encodeWithSignature("exchange_underlying(uint256,uint256,uint256,uint256)", i, j, dx, min_dy)
                : abi.encodeWithSignature("exchange(uint256,uint256,uint256,uint256)", i, j, dx, min_dy);
        } else {
            return underlying
                ? abi.encodeWithSignature("exchange_underlying(int128,int128,uint256,uint256)", i, j, dx, min_dy)
                : abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)", i, j, dx, min_dy);
        }
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
        _approve_tokens(t0Approve, t1Approve, t2Approve, t3Approve, type(uint256).max);
        _execute(msg.data);
        _approve_tokens(t0Approve, t1Approve, t2Approve, t3Approve, 1);
        (tokensToEnable, tokensToDisable) = (lpTokenMask, 0);
    }

    /// @notice Adds given amount of asset as liquidity to the pool
    /// @param amount Amount to deposit
    /// @param i Index of the asset to deposit
    /// @param minAmount Minimum amount of LP tokens to receive
    function add_liquidity_one_coin(uint256 amount, uint256 i, uint256 minAmount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) =
            _add_liquidity_one_coin_impl(i, _getAddLiquidityOneCoinCallData(i, amount, minAmount), false); // F: [ACV1-8]
    }

    /// @notice Adds the entire balance of asset as liquidity to the pool, disables this asset
    /// @param i Index of the asset to deposit
    /// @param rateMinRAY Minimum exchange rate between deposited asset and LP token, scaled by 1e27
    function add_all_liquidity_one_coin(uint256 i, uint256 rateMinRAY)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        address tokenIn = _get_token(i, false);
        uint256 amount = IERC20(tokenIn).balanceOf(creditAccount); // F: [ACV1-9]
        if (amount <= 1) return (0, 0);

        unchecked {
            amount--; // F: [ACV1-9]
        }
        uint256 minAmount = (amount * rateMinRAY) / RAY; // F: [ACV1-9]
        (tokensToEnable, tokensToDisable) =
            _add_liquidity_one_coin_impl(i, _getAddLiquidityOneCoinCallData(i, amount, minAmount), true); // F: [ACV1-9]
    }

    /// @dev Internal implementation of `add_liquidity_one_coin` and `add_all_liquidity_one_coin`
    ///      - passes calldata to the target contract
    ///      - sets max approval for the input token before the call and resets it to 1 after
    ///      - enables LP token
    ///      - disables input token only when adding the entire balance
    function _add_liquidity_one_coin_impl(uint256 i, bytes memory callData, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approve_token(i, false, type(uint256).max);
        _execute(callData);
        _approve_token(i, false, 1);
        (tokensToEnable, tokensToDisable) = (lpTokenMask, disableTokenIn ? _get_token_mask(i, false) : 0);
    }

    /// @dev Returns calldata for `ICurvePool.add_liquidity` with one input asset
    function _getAddLiquidityOneCoinCallData(uint256 i, uint256 amount, uint256 minAmount)
        internal
        view
        returns (bytes memory)
    {
        if (nCoins == 2) {
            uint256[2] memory amounts;
            if (i > 1) revert IncorrectIndexException();
            amounts[i] = amount;
            return abi.encodeCall(ICurvePool2Assets.add_liquidity, (amounts, minAmount)); // F: [ACV1-8, ACV1-9]
        }
        if (nCoins == 3) {
            uint256[3] memory amounts;
            if (i > 2) revert IncorrectIndexException();
            amounts[i] = amount;
            return abi.encodeCall(ICurvePool3Assets.add_liquidity, (amounts, minAmount)); // F: [ACV1-8, ACV1-9]
        }
        if (nCoins == 4) {
            uint256[4] memory amounts;
            if (i > 3) revert IncorrectIndexException();
            amounts[i] = amount;
            return abi.encodeCall(ICurvePool4Assets.add_liquidity, (amounts, minAmount)); // F: [ACV1-8, ACV1-9]
        }
        revert("Incorrect nCoins");
    }

    // ---------------- //
    // REMOVE LIQUIDITY //
    // ---------------- //

    /// @dev Internal implementation of `remove_liquidity`
    ///      - passes calldata to the target contract
    ///      - enables all pool tokens
    function _remove_liquidity() internal returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        _execute(msg.data);
        (tokensToEnable, tokensToDisable) = (token0Mask | token1Mask | token2Mask | token3Mask, 0); // F: [ACV1_2-5, ACV1_3-5, ACV1_4-5]
    }

    /// @dev Internal implementation of `remove_liquidity_imbalance`
    ///      - passes calldata to the target contract
    ///      - enables specified pool tokens
    function _remove_liquidity_imbalance(bool t0Enable, bool t1Enable, bool t2Enable, bool t3Enable)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(msg.data);

        if (t0Enable) tokensToEnable = tokensToEnable.enable(_get_token_mask(0, false)); // F: [ACV1_2-6, ACV1_3-6, ACV1_4-6]
        if (t1Enable) tokensToEnable = tokensToEnable.enable(_get_token_mask(1, false)); // F: [ACV1_2-6, ACV1_3-6, ACV1_4-6]
        if (t2Enable) tokensToEnable = tokensToEnable.enable(_get_token_mask(2, false)); // F: [ACV1_3-6, ACV1_4-6]
        if (t3Enable) tokensToEnable = tokensToEnable.enable(_get_token_mask(3, false)); // F: [ACV1_4-6]
        tokensToDisable = 0; // F: [ACV1_2-6, ACV1_3-6, ACV1_4-6]
    }

    /// @notice Removes liquidity from the pool in a specified asset
    /// @param _token_amount Amount of liquidity to remove
    /// @param i Index of the asset to withdraw
    /// @param min_amount Minimum amount of asset to receive
    function remove_liquidity_one_coin(uint256 _token_amount, uint256 i, uint256 min_amount)
        external
        virtual
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _remove_liquidity_one_coin(_token_amount, i, min_amount);
    }

    /// @dev Internal implementation of `remove_liquidity_one_coin`
    function _remove_liquidity_one_coin(uint256 amount, uint256 i, uint256 min_amount)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) =
            _remove_liquidity_one_coin_impl(i, _getRemoveLiquidityOneCoinCallData(i, amount, min_amount), false); // F: [ACV1-10]
    }

    /// @notice Removes all liquidity from the pool in a specified asset
    /// @param i Index of the asset to withdraw
    /// @param rateMinRAY Minimum exchange rate between LP token and received token, scaled by 1e27
    function remove_all_liquidity_one_coin(uint256 i, uint256 rateMinRAY)
        external
        virtual
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _remove_all_liquidity_one_coin(i, rateMinRAY);
    }

    /// @dev Internal implementation of `remove_all_liquidity_one_coin`
    function _remove_all_liquidity_one_coin(uint256 i, uint256 rateMinRAY)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        uint256 amount = IERC20(lp_token).balanceOf(creditAccount); // F: [ACV1-11]
        if (amount <= 1) return (0, 0);

        unchecked {
            amount--; // F: [ACV1-11]
        }
        uint256 minAmount = (amount * rateMinRAY) / RAY; // F: [ACV1-11]
        (tokensToEnable, tokensToDisable) =
            _remove_liquidity_one_coin_impl(i, _getRemoveLiquidityOneCoinCallData(i, amount, minAmount), true); // F: [ACV1-11]
    }

    /// @dev Internal implementation of `remove_liquidity_one_coin` and `remove_all_liquidity_one_coin`
    ///      - passes calldata to the targe contract
    ///      - enables received asset
    ///      - disables LP token only when removing all liquidity
    function _remove_liquidity_one_coin_impl(uint256 i, bytes memory callData, bool disableLP)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(callData);
        (tokensToEnable, tokensToDisable) = (_get_token_mask(i, false), disableLP ? lpTokenMask : 0);
    }

    /// @dev Returns calldata for `ICurvePool.remove_liquidity_one_coin` call
    function _getRemoveLiquidityOneCoinCallData(uint256 i, uint256 amount, uint256 minAmount)
        internal
        view
        returns (bytes memory)
    {
        if (use256) {
            return abi.encodeWithSignature("remove_liquidity_one_coin(uint256,uint256,uint256)", amount, i, minAmount);
        } else {
            return abi.encodeWithSignature("remove_liquidity_one_coin(uint256,int128,uint256)", amount, i, minAmount);
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Returns token `i`'s address
    function _get_token(uint256 i, bool underlying) internal view returns (address addr) {
        if (i == 0) {
            addr = underlying ? underlying0 : token0;
        } else if (i == 1) {
            addr = underlying ? underlying1 : token1;
        } else if (i == 2) {
            addr = underlying ? underlying2 : token2;
        } else if (i == 3) {
            addr = underlying ? underlying3 : token3;
        }

        if (addr == address(0)) revert IncorrectIndexException();
    }

    /// @dev Returns token `i`'s mask
    function _get_token_mask(uint256 i, bool underlying) internal view returns (uint256 mask) {
        if (i == 0) {
            mask = underlying ? underlying0Mask : token0Mask;
        } else if (i == 1) {
            mask = underlying ? underlying1Mask : token1Mask;
        } else if (i == 2) {
            mask = underlying ? underlying2Mask : token2Mask;
        } else if (i == 3) {
            mask = underlying ? underlying3Mask : token3Mask;
        }

        if (mask == 0) revert IncorrectIndexException();
    }

    /// @dev Sets target contract's approval for token `i` to `amount`
    function _approve_token(uint256 i, bool underlying, uint256 amount) internal {
        _approveToken(_get_token(i, underlying), amount);
    }

    /// @dev Sets target contract's approval for specified tokens to `amount`
    function _approve_tokens(bool t0Approve, bool t1Approve, bool t2Approve, bool t3Approve, uint256 amount) internal {
        if (t0Approve) _approveToken(token0, amount); // F: [ACV1_2-4, ACV1_3-4, ACV1_4-4]
        if (t1Approve) _approveToken(token1, amount); // F: [ACV1_2-4, ACV1_3-4, ACV1_4-4]
        if (t2Approve) _approveToken(token2, amount); // F: [ACV1_3-4, ACV1_4-4]
        if (t3Approve) _approveToken(token3, amount); // F: [ACV1_4-4]
    }

    // ------------ //
    // CALCULATIONS //
    // ------------ //

    /// @notice Returns the amount of LP token received for adding a single asset to the pool
    /// @param amount Amount to deposit
    /// @param i Index of the asset to deposit
    function calc_add_one_coin(uint256 amount, uint256 i) external view override returns (uint256) {
        bool success;
        bytes memory returndata;
        bytes memory callData;
        bytes memory callDataAlt;

        if (nCoins == 2) {
            uint256[2] memory amounts;
            amounts[i] = amount;

            callData = abi.encodeWithSignature("calc_token_amount(uint256[2],bool)", amounts, true);
            callDataAlt = abi.encodeWithSignature("calc_token_amount(uint256[2])", amounts);
        } else if (nCoins == 3) {
            uint256[3] memory amounts;
            amounts[i] = amount;

            callData = abi.encodeWithSignature("calc_token_amount(uint256[3],bool)", amounts, true);
            callDataAlt = abi.encodeWithSignature("calc_token_amount(uint256[3])", amounts);
        } else if (nCoins == 4) {
            uint256[4] memory amounts;
            amounts[i] = amount;

            callData = abi.encodeWithSignature("calc_token_amount(uint256[4],bool)", amounts, true);
            callDataAlt = abi.encodeWithSignature("calc_token_amount(uint256[4])", amounts);
        }

        (success, returndata) = targetContract.staticcall(callData);

        if (!success || returndata.length == 0) {
            (success, returndata) = targetContract.staticcall(callDataAlt);
        }

        if (success && returndata.length > 0) {
            return abi.decode(returndata, (uint256));
        } else {
            revert("Failed to fetch token amount");
        }
    }
}
