// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {ITokenTestSuite} from "@gearbox-protocol/core-v2/contracts/test/interfaces/ITokenTestSuite.sol";

import {IAddressProvider} from "@gearbox-protocol/core-v2/contracts/interfaces/IAddressProvider.sol";
import {PoolService} from "@gearbox-protocol/core-v2/contracts/pool/PoolService.sol";

import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";
import {LinearInterestRateModel} from "@gearbox-protocol/core-v2/contracts/pool/LinearInterestRateModel.sol";

import {IwstETH} from "../../integrations/lido/IwstETH.sol";
import "../lib/constants.sol";

uint256 constant U_OPTIMAL = 80_00;
uint256 constant U_RESERVE = 90_00;
uint256 constant R_BASE = 2_00;
uint256 constant R_SLOPE_1 = 5_00;
uint256 constant R_SLOPE_2 = 40_00;
uint256 constant R_SLOPE_3 = 75_00;

uint256 constant EXPECTED_LIQUIDITY_LIMIT = 10_000 * WAD;
uint256 constant WITHDRAW_FEE = 1_00;

/// @title WstETHPoolSetup
/// @notice Setup and add wstETH pool to the system
contract WstETHPoolSetup {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    constructor(address addressProvider, address wstETH, ITokenTestSuite tokensTestSuite, address root) {
        LinearInterestRateModel linearModel = new LinearInterestRateModel(
            U_OPTIMAL,
            U_RESERVE,
            R_BASE,
            R_SLOPE_1,
            R_SLOPE_2,
            R_SLOPE_3,
            false
        );

        PoolService pool = new PoolService(
            addressProvider,
            wstETH,
            address(linearModel),
            EXPECTED_LIQUIDITY_LIMIT
        );

        ContractsRegister cr = ContractsRegister(IAddressProvider(addressProvider).getContractsRegister());

        evm.prank(root);
        pool.setWithdrawFee(WITHDRAW_FEE);

        evm.prank(root);
        cr.addPool(address(pool));

        uint256 poolLiquidityAmount = EXPECTED_LIQUIDITY_LIMIT / 3;

        uint256 wrappedAmount = IwstETH(wstETH).getStETHByWstETH(poolLiquidityAmount);

        address stETH = IwstETH(wstETH).stETH();

        tokensTestSuite.mint(stETH, address(this), wrappedAmount);

        tokensTestSuite.approve(stETH, address(this), wstETH);

        uint256 updatedPoolLiquidityAmount = IwstETH(wstETH).wrap(wrappedAmount);
        IwstETH(wstETH).approve(address(pool), type(uint256).max);

        pool.addLiquidity(updatedPoolLiquidityAmount, address(this), 0);
    }
}
