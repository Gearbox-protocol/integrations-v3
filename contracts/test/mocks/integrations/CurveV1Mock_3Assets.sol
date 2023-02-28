// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICRVToken} from "../../../integrations/curve/ICRVToken.sol";
import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {CurveV1Mock} from "./CurveV1Mock.sol";
import {N_COINS, ICurvePool3Assets} from "../../../integrations/curve/ICurvePool_3.sol";

contract CurveV1Mock_3Assets is CurveV1Mock, ICurvePool3Assets {
    using SafeERC20 for IERC20;

    constructor(address[] memory _coins, address[] memory _underlying_coins) CurveV1Mock(_coins, _underlying_coins) {}

    function add_liquidity(uint256[N_COINS] memory amounts, uint256 min_mint_amount) external {
        for (uint256 i = 0; i < N_COINS; i++) {
            if (amounts[i] > 0) {
                IERC20(_coins[i]).transferFrom(msg.sender, address(this), amounts[i]);
            }
        }

        if (real_liquidity_mode) {
            uint256 mintAmount = calc_token_amount(amounts, true);
            require(mintAmount >= min_mint_amount);
            ICRVToken(token).mint(msg.sender, mintAmount);
        } else {
            ICRVToken(token).mint(msg.sender, min_mint_amount);
        }
    }

    function remove_liquidity(uint256 _amount, uint256[N_COINS] memory min_amounts) external {
        for (uint256 i = 0; i < N_COINS; i++) {
            if (real_liquidity_mode) {
                uint256 amountOut = ((_amount * withdraw_rates_RAY[int128(uint128(i))]) / N_COINS) / RAY;
                require(amountOut > min_amounts[i]);
                IERC20(_coins[i]).transfer(msg.sender, amountOut);
            } else if (min_amounts[i] > 0) {
                IERC20(_coins[i]).transfer(msg.sender, min_amounts[i]);
            }
        }

        ICRVToken(token).burnFrom(msg.sender, _amount);
    }

    function remove_liquidity_imbalance(uint256[N_COINS] memory amounts, uint256 max_burn_amount) external {
        for (uint256 i = 0; i < N_COINS; i++) {
            if (amounts[i] > 0) {
                IERC20(_coins[i]).transfer(msg.sender, amounts[i]);
            }
        }

        if (real_liquidity_mode) {
            uint256 burnAmount = calc_token_amount(amounts, false);
            require(burnAmount <= max_burn_amount);
            ICRVToken(token).burnFrom(msg.sender, burnAmount);
        } else {
            ICRVToken(token).burnFrom(msg.sender, max_burn_amount);
        }
    }

    function calc_token_amount(uint256[N_COINS] memory amounts, bool deposit) public view returns (uint256 amount) {
        for (uint256 i = 0; i < N_COINS; ++i) {
            if (deposit) {
                amount += (amounts[i] * deposit_rates_RAY[int128(int256(i))]) / RAY;
            } else {
                amount += (amounts[i] * RAY) / withdraw_rates_RAY[int128(int256(i))];
            }
        }
    }

    function get_twap_balances(uint256[N_COINS] calldata _first_balances, uint256[N_COINS] calldata, uint256)
        external
        pure
        returns (uint256[N_COINS] memory)
    {
        return _first_balances;
    }

    function get_balances() external pure returns (uint256[N_COINS] memory) {
        return [uint256(0), uint256(0), uint256(0)];
    }

    function get_previous_balances() external pure returns (uint256[N_COINS] memory) {
        return [uint256(0), uint256(0), uint256(0)];
    }

    function get_price_cumulative_last() external pure returns (uint256[N_COINS] memory) {
        return [uint256(0), uint256(0), uint256(0)];
    }
}
