// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {TokensTestSuite} from "./TokensTestSuite.sol";
import {Tokens} from "../config/Tokens.sol";

import {IAddressProvider} from "@gearbox-protocol/core-v2/contracts/interfaces/IAddressProvider.sol";
import {PoolService} from "@gearbox-protocol/core-v2/contracts/pool/PoolService.sol";

import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";
import {LinearInterestRateModel} from "@gearbox-protocol/core-v2/contracts/pool/LinearInterestRateModel.sol";

import "../lib/constants.sol";

uint256 constant U_OPTIMAL = 80_00;
uint256 constant R_BASE = 0;
uint256 constant R_SLOPE_1 = 4_00;
uint256 constant R_SLOPE_2 = 100_00;

uint256 constant EXPECTED_LIQUIDITY_LIMIT = 500_000 * WAD;
uint256 constant WITHDRAW_FEE = 0;

/// @title OHMPoolSetup
/// @notice Setup and add OHM pool to the system
contract OHMPoolSetup {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    constructor(address addressProvider, TokensTestSuite tokensTestSuite, address root) {
        LinearInterestRateModel linearModel = new LinearInterestRateModel(
            U_OPTIMAL,
            R_BASE,
            R_SLOPE_1,
            R_SLOPE_2
        );

        PoolService pool = new PoolService(
            addressProvider,
            tokensTestSuite.addressOf(Tokens.OHM),
            address(linearModel),
            EXPECTED_LIQUIDITY_LIMIT
        );

        ContractsRegister cr = ContractsRegister(IAddressProvider(addressProvider).getContractsRegister());

        evm.prank(root);
        cr.addPool(address(pool));

        uint256 poolLiquidityAmount = EXPECTED_LIQUIDITY_LIMIT / 3;

        tokensTestSuite.mint(Tokens.OHM, address(this), poolLiquidityAmount);

        tokensTestSuite.approve(Tokens.OHM, address(this), address(pool));

        pool.addLiquidity(poolLiquidityAmount, address(this), 0);
    }
}
