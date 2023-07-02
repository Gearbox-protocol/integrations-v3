// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {WAD, RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {ICurvePool} from "../../../integrations/curve/ICurvePool.sol";
import {N_COINS, ICurvePool2Assets} from "../../../integrations/curve/ICurvePool_2.sol";
import {ICRVToken} from "../../../integrations/curve/ICRVToken.sol";

import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

// EXCEPTIONS

contract CurveV1MetapoolMock is ICurvePool, ICurvePool2Assets {
    using SafeERC20 for IERC20;

    address public override token;
    address public lp_token;

    address[] internal _coins;
    address public basePool;
    mapping(int128 => mapping(int128 => uint256)) rates_RAY;
    mapping(int128 => mapping(int128 => uint256)) rates_RAY_underlying;
    mapping(int128 => uint256) public withdraw_rates_RAY;
    mapping(int128 => uint256) public deposit_rates_RAY;

    uint256 public virtualPrice;

    bool real_liquidity_mode;

    bool isCryptoPool;

    constructor(address _token0, address _basePool) {
        _coins.push(_token0);
        _coins.push(ICurvePool(_basePool).token());

        address _token = address(new ERC20Mock("CRVMock", "CRV for CurvePoolMock", 18));
        token = _token;
        lp_token = _token;
        virtualPrice = WAD;
        basePool = _basePool;
    }

    function setIsCryptoPool(bool _isCryptoPool) external {
        isCryptoPool = _isCryptoPool;
    }

    function setRealLiquidityMode(bool val) external {
        real_liquidity_mode = val;
    }

    function setRate(int128 i, int128 j, uint256 rate_RAY) external {
        rates_RAY[i][j] = rate_RAY;
        rates_RAY[j][i] = (RAY * RAY) / rate_RAY;
    }

    function setRateUnderlying(int128 i, int128 j, uint256 rate_RAY) external {
        rates_RAY_underlying[i][j] = rate_RAY;
        rates_RAY_underlying[j][i] = (RAY * RAY) / rate_RAY;
    }

    function setWithdrawRate(int128 i, uint256 rate_RAY) external {
        withdraw_rates_RAY[i] = rate_RAY;
    }

    function setDepositRate(int128 i, uint256 rate_RAY) external {
        deposit_rates_RAY[i] = rate_RAY;
    }

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
        return [uint256(0), uint256(0)];
    }

    function get_previous_balances() external pure returns (uint256[N_COINS] memory) {
        return [uint256(0), uint256(0)];
    }

    function get_price_cumulative_last() external pure returns (uint256[N_COINS] memory) {
        return [uint256(0), uint256(0)];
    }

    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external override {
        exchange(int128(int256(i)), int128(int256(j)), dx, min_dy);
    }

    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) public override {
        uint256 dy = get_dy(i, j, dx);

        require(dy >= min_dy, "CurveV1Mock: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(_coins[uint256(uint128(i))]).safeTransferFrom(msg.sender, address(this), dx);
        IERC20(_coins[uint256(uint128(j))]).safeTransfer(msg.sender, dy);
    }

    function exchange_underlying(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external override {
        exchange_underlying(int128(int256(i)), int128(int256(j)), dx, min_dy);
    }

    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) public override {
        if (i == 0) {
            IERC20(_coins[0]).transferFrom(msg.sender, address(this), dx);
        } else {
            address tokenIn = underlying_coins(uint256(uint128(i)));
            IERC20(tokenIn).transferFrom(msg.sender, address(this), dx);
        }

        int128 base_i = i > 0 ? int128(uint128(1)) : int128(uint128(0));
        int128 base_j = j > 0 ? int128(uint128(1)) : int128(uint128(0));

        uint256 dy = get_dy(base_i, base_j, dx);
        uint256 dy_underlying = get_dy_underlying(i, j, dx);
        require(dy_underlying >= min_dy, "CurveV1Mock: INSUFFICIENT_OUTPUT_AMOUNT");

        if (j == 0) {
            IERC20(_coins[0]).transfer(msg.sender, dy_underlying);
        } else {
            address tokenOut = underlying_coins(uint256(uint128(j)));
            ICurvePool(basePool).remove_liquidity_one_coin(dy, j - 1, dy_underlying);
            IERC20(tokenOut).transfer(msg.sender, dy_underlying);
        }
    }

    function mintLP(address to, uint256 amount) external {
        ICRVToken(token).mint(to, amount);
    }

    function remove_liquidity_one_coin(uint256 _token_amount, uint256 i, uint256 min_amount) external override {
        remove_liquidity_one_coin(_token_amount, int128(int256(i)), min_amount);
    }

    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) public override {
        ICRVToken(token).burnFrom(msg.sender, _token_amount);

        uint256 amountOut;

        if (real_liquidity_mode) {
            amountOut = calc_withdraw_one_coin(_token_amount, i);
        } else {
            amountOut = min_amount;
        }

        IERC20(_coins[uint256(uint128(i))]).safeTransfer(msg.sender, amountOut);
    }

    function get_dy_underlying(uint256 i, uint256 j, uint256 dx) public view override returns (uint256) {
        return get_dy_underlying(uint256(int256(i)), uint256(int256(j)), dx);
    }

    function get_dy_underlying(int128 i, int128 j, uint256 dx) public view override returns (uint256) {
        return (rates_RAY_underlying[i][j] * dx) / RAY;
    }

    function get_dy(uint256 i, uint256 j, uint256 dx) public view override returns (uint256) {
        return get_dy(uint256(int256(i)), uint256(int256(j)), dx);
    }

    function get_dy(int128 i, int128 j, uint256 dx) public view override returns (uint256) {
        return (rates_RAY[i][j] * dx) / RAY;
    }

    function balances(uint256 i) public view returns (uint256) {
        return IERC20(_coins[i]).balanceOf(address(this));
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

    function balances(int128 i) external view returns (uint256) {
        return balances(uint256(uint128(i)));
    }

    function coins(uint256 i) public view returns (address) {
        return _coins[i];
    }

    function coins(int128 i) public view returns (address) {
        return _coins[uint256(uint128(i))];
    }

    function underlying_coins(uint256 i) public view returns (address) {
        if (i == 0) {
            return _coins[0];
        } else {
            return ICurvePool(basePool).coins(i - 1);
        }
    }

    function underlying_coins(int128 i) public view returns (address) {
        if (i == 0) {
            return _coins[0];
        } else {
            return ICurvePool(basePool).coins(uint256(uint128(i)) - 1);
        }
    }

    function A() external pure returns (uint256) {
        return 0;
    }

    function A_precise() external pure returns (uint256) {
        return 0;
    }

    function calc_withdraw_one_coin(uint256 _burn_amount, uint256 i) external view returns (uint256) {
        return calc_withdraw_one_coin(_burn_amount, int128(int256(i)));
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

    function mid_fee() external view returns (uint256) {
        if (isCryptoPool) {
            return 0;
        }

        revert("Not a crypto pool");
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

    // Some pools implement ERC20

    function name() external pure returns (string memory) {
        return "";
    }

    function symbol() external pure returns (string memory) {
        return "";
    }

    function decimals() external pure returns (uint256) {
        return 0;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }
}
