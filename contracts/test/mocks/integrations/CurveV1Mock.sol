// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {WAD, RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {ICurvePool} from "../../../integrations/curve/ICurvePool.sol";
import {ICRVToken} from "../../../integrations/curve/ICRVToken.sol";

import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {cERC20Mock} from "../token/cERC20Mock.sol";

// EXCEPTIONS

contract CurveV1Mock is ICurvePool {
    using SafeERC20 for IERC20;

    address public override token;
    address public lp_token;

    address[] internal _coins;
    address[] internal _underlying_coins;
    mapping(int128 => mapping(int128 => uint256)) rates_RAY;
    mapping(int128 => mapping(int128 => uint256)) rates_RAY_underlying;

    mapping(int128 => uint256) public withdraw_rates_RAY;
    mapping(int128 => uint256) public deposit_rates_RAY;

    uint256 public virtualPrice;

    bool public real_liquidity_mode;

    bool isCryptoPool;

    constructor(address[] memory coins_, address[] memory underlying_coins_) {
        _coins = coins_;
        _underlying_coins = underlying_coins_;

        address _token = address(new ERC20Mock("CRVMock", "CRV for CurvePoolMock", 18));
        token = _token;
        lp_token = _token;
        virtualPrice = WAD;
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

    function setWithdrawRate(int128 i, uint256 rate_RAY) external {
        withdraw_rates_RAY[i] = rate_RAY;
    }

    function setDepositRate(int128 i, uint256 rate_RAY) external {
        deposit_rates_RAY[i] = rate_RAY;
    }

    function setRateUnderlying(int128 i, int128 j, uint256 rate_RAY) external {
        rates_RAY_underlying[i][j] = rate_RAY;
        rates_RAY_underlying[j][i] = (RAY * RAY) / rate_RAY;
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
        address coinIn = _coins[uint256(uint128(i))];
        address underlyingIn = _underlying_coins[uint256(uint128(i))];

        address coinOut = _coins[uint256(uint128(j))];
        address underlyingOut = _underlying_coins[uint256(uint128(j))];

        uint256 dy = get_dy_underlying(i, j, dx);

        require(dy >= min_dy, "CurveV1Mock: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(underlyingIn).safeTransferFrom(msg.sender, address(this), dx);
        IERC20(underlyingIn).approve(coinIn, dx);
        cERC20Mock(coinIn).mint(address(this), dx);

        cERC20Mock(coinOut).redeem(address(this), dy);
        IERC20(underlyingOut).safeTransfer(msg.sender, dy);
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

    function get_dy_underlying(int128 i, int128 j, uint256 dx) public view override returns (uint256) {
        return (rates_RAY_underlying[i][j] * dx) / RAY;
    }

    function get_dy_underlying(uint256 i, uint256 j, uint256 dx) public view override returns (uint256) {
        return get_dy_underlying(uint256(int256(i)), uint256(int256(j)), dx);
    }

    function get_dy(int128 i, int128 j, uint256 dx) public view override returns (uint256) {
        return (rates_RAY[i][j] * dx) / RAY;
    }

    function get_dy(uint256 i, uint256 j, uint256 dx) public view override returns (uint256) {
        return get_dy(uint256(int256(i)), uint256(int256(j)), dx);
    }

    function balances(uint256 i) external view override returns (uint256) {
        return IERC20(_coins[i]).balanceOf(address(this));
    }

    function balances(int128 i) external view override returns (uint256) {
        return IERC20(_coins[uint256(int256(i))]).balanceOf(address(this));
    }

    function coins(uint256 i) external view override returns (address) {
        return _coins[i];
    }

    function coins(int128 i) external view override returns (address) {
        return _coins[uint256(int256(i))];
    }

    function underlying_coins(uint256 i) external view override returns (address) {
        return _underlying_coins[i];
    }

    function underlying_coins(int128 i) external view override returns (address) {
        return _underlying_coins[uint256(int256(i))];
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

    function mintLP(address to, uint256 amount) external {
        ICRVToken(token).mint(to, amount);
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

    function calc_withdraw_one_coin(uint256 _burn_amount, uint256 i) external view returns (uint256) {
        return calc_withdraw_one_coin(_burn_amount, int128(int256(i)));
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

    function mid_fee() external view returns (uint256) {
        if (isCryptoPool) {
            return 0;
        }

        revert("Not a crypto pool");
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
