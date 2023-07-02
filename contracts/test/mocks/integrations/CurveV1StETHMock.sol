// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {WAD, RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {N_COINS, ICurvePoolStETH} from "../../../integrations/curve/ICurvePoolStETH.sol";
import {ICRVToken} from "../../../integrations/curve/ICRVToken.sol";

import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

contract CurveV1StETHMock is ICurvePoolStETH {
    error NotImplementedException();

    using SafeERC20 for IERC20;

    address public override lp_token;
    address public token;

    address[] public override coins;
    mapping(int128 => mapping(int128 => uint256)) rates_RAY;

    mapping(int128 => uint256) public withdraw_rates_RAY;
    mapping(int128 => uint256) public deposit_rates_RAY;

    uint256 public virtualPrice;

    bool real_liquidity_mode;

    constructor(address[] memory _coins) {
        coins = _coins;
        lp_token = address(new ERC20Mock("CRVMock", "CRV for CurvePoolMock", 18));
        token = lp_token;
        virtualPrice = WAD;
    }

    function setRate(int128 i, int128 j, uint256 rate_RAY) external {
        rates_RAY[i][j] = rate_RAY;
        rates_RAY[j][i] = (RAY * RAY) / rate_RAY;
    }

    function setRealLiquidityMode(bool val) external {
        real_liquidity_mode = val;
    }

    function setWithdrawRate(int128 i, uint256 rate_RAY) external {
        withdraw_rates_RAY[i] = rate_RAY;
    }

    function setDepositRate(int128 i, uint256 rate_RAY) external {
        deposit_rates_RAY[i] = rate_RAY;
    }

    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable override {
        uint256 dy = get_dy(i, j, dx);

        require(dy >= min_dy, "CurveV1Mock: INSUFFICIENT_OUTPUT_AMOUNT");

        if (i == 0) {
            require(msg.value == dx);
            IERC20(coins[uint256(uint128(j))]).safeTransfer(msg.sender, dy);
        } else {
            require(msg.value == 0);
            IERC20(coins[uint256(uint128(i))]).safeTransferFrom(msg.sender, address(this), dx);
            payable(msg.sender).transfer(dy);
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

    function add_liquidity(uint256[N_COINS] memory amounts, uint256 min_mint_amount) external payable {
        require(msg.value == amounts[0]);
        IERC20(coins[1]).transferFrom(msg.sender, address(this), amounts[1]);

        if (real_liquidity_mode) {
            uint256 mintAmount = calc_token_amount(amounts, true);
            require(mintAmount >= min_mint_amount);
            ICRVToken(token).mint(msg.sender, mintAmount);
        } else {
            ICRVToken(token).mint(msg.sender, min_mint_amount);
        }
    }

    function remove_liquidity(uint256 _amount, uint256[N_COINS] memory min_amounts) external {
        if (real_liquidity_mode) {
            uint256 amountOut = ((_amount * withdraw_rates_RAY[int128(uint128(0))]) / N_COINS) / RAY;
            require(amountOut > min_amounts[0]);
            payable(msg.sender).transfer(amountOut);

            amountOut = ((_amount * withdraw_rates_RAY[int128(uint128(1))]) / N_COINS) / RAY;
            require(amountOut > min_amounts[1]);
            IERC20(coins[1]).transfer(msg.sender, amountOut);
        } else {
            payable(msg.sender).transfer(min_amounts[0]);
            IERC20(coins[1]).transfer(msg.sender, min_amounts[1]);
        }

        ICRVToken(lp_token).burnFrom(msg.sender, _amount);
    }

    function exchange_underlying(
        int128, //i,
        int128, //j,
        uint256, // dx,
        uint256 // min_dy
    ) external pure override {
        revert NotImplementedException();
    }

    function get_dy_underlying(
        int128, //i,
        int128, //j,
        uint256 //dx
    ) external pure override returns (uint256) {
        revert NotImplementedException();
    }

    function get_dy(int128 i, int128 j, uint256 dx) public view override returns (uint256) {
        return (rates_RAY[i][j] * dx) / RAY;
    }

    function get_virtual_price() external view override returns (uint256) {
        return virtualPrice;
    }

    function set_virtual_price(uint256 _price) external {
        virtualPrice = _price;
    }

    function virtual_price() external view override returns (uint256) {
        return virtualPrice;
    }

    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external {
        ICRVToken(lp_token).burnFrom(msg.sender, _token_amount);
        if (real_liquidity_mode) {
            if (i == 0) {
                payable(msg.sender).transfer(calc_withdraw_one_coin(_token_amount, 0));
            } else {
                IERC20(coins[1]).transfer(msg.sender, calc_withdraw_one_coin(_token_amount, 1));
            }
        } else {
            if (i == 0) {
                payable(msg.sender).transfer(min_amount);
            } else {
                IERC20(coins[1]).transfer(msg.sender, min_amount);
            }
        }
    }

    function remove_liquidity_imbalance(uint256[N_COINS] memory amounts, uint256 max_burn_amount) external {
        payable(msg.sender).transfer(amounts[0]);
        IERC20(coins[1]).transfer(msg.sender, amounts[1]);

        if (real_liquidity_mode) {
            uint256 burnAmount = calc_token_amount(amounts, false);
            require(burnAmount <= max_burn_amount);
            ICRVToken(token).burnFrom(msg.sender, burnAmount);
        } else {
            ICRVToken(token).burnFrom(msg.sender, max_burn_amount);
        }
    }

    function balances(uint256 i) external view returns (uint256) {
        if (i == 0) {
            return address(this).balance;
        } else {
            return IERC20(coins[1]).balanceOf(address(this));
        }
    }

    function A() external pure returns (uint256) {
        return 0;
    }

    function A_precise() external pure returns (uint256) {
        return 0;
    }

    function calc_withdraw_one_coin(uint256 amount, int128 coin) public view returns (uint256) {
        return (amount * withdraw_rates_RAY[coin]) / RAY;
    }

    function admin_balances(uint256) external pure returns (uint256) {
        return 0;
    }

    function admin() external pure returns (address) {
        return address(0);
    }

    function fee() external pure returns (uint256) {
        return 0;
    }

    function admin_fee() external pure returns (uint256) {
        return 0;
    }

    function block_timestamp_last() external pure returns (uint256) {
        return 0;
    }

    function initial_A() external pure returns (uint256) {
        return 0;
    }

    function future_A() external pure returns (uint256) {
        return 0;
    }

    function initial_A_time() external pure returns (uint256) {
        return 0;
    }

    function future_A_time() external pure returns (uint256) {
        return 0;
    }
}
