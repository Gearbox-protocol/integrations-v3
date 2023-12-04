// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICurvePool3Assets} from "../../../../integrations/curve/ICurvePool_3.sol";
import {ICurveV1_3AssetsAdapter} from "../../../../interfaces/curve/ICurveV1_3AssetsAdapter.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";

import {CurveV1Calls, CurveV1Multicaller} from "../../../multicall/curve/CurveV1_Calls.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_3CRVEquivalenceTest is LiveTestHelper {
    using CurveV1Calls for CurveV1Multicaller;

    BalanceComparator comparator;

    function setUp() public attachOrLiveTest {
        _setUp();

        // TOKENS TO TRACK ["3Crv", "DAI", "USDC", "USDT"]
        Tokens[4] memory tokensToTrack = [Tokens._3Crv, Tokens.DAI, Tokens.USDC, Tokens.USDT];

        // STAGES
        string[9] memory stages = [
            "after_exchange",
            "after_add_liquidity",
            "after_remove_liquidity",
            "after_remove_liquidity_one_coin",
            "after_remove_liquidity_imbalance",
            "after_add_liquidity_one_coin",
            "after_exchange_diff",
            "after_add_diff_liquidity_one_coin",
            "after_remove_diff_liquidity_one_coin"
        ];

        /// @notice Sets comparator for this equivalence test

        uint256 len = stages.length;
        string[] memory _stages = new string[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _stages[i] = stages[i];
            }
        }

        len = tokensToTrack.length;
        Tokens[] memory _tokensToTrack = new Tokens[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _tokensToTrack[i] = tokensToTrack[i];
            }
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    /// HELPER

    function compareBehavior(address creditAccount, address curvePoolAddr, bool isAdapter) internal {
        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);

            vm.startPrank(USER);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.exchange(int128(0), int128(2), 2000 * WAD, 1500 * (10 ** 6)))
            );
            comparator.takeSnapshot("after_exchange", creditAccount);

            uint256[3] memory amounts = [1000 * WAD, 0, 1000 * (10 ** 6)];

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.add_liquidity(amounts, 0)));
            comparator.takeSnapshot("after_add_liquidity", creditAccount);

            amounts = [uint256(0), 0, 0];

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.remove_liquidity(500 * WAD, amounts)));
            comparator.takeSnapshot("after_remove_liquidity", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.remove_liquidity_one_coin(500 * WAD, int128(1), 0))
            );
            comparator.takeSnapshot("after_remove_liquidity_one_coin", creditAccount);

            amounts = [500 * WAD, 0, 100 * (10 ** 6)];

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.remove_liquidity_imbalance(amounts, type(uint256).max))
            );
            comparator.takeSnapshot("after_remove_liquidity_imbalance", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.add_liquidity_one_coin(100 * WAD, uint256(0), 50 * WAD))
            );
            comparator.takeSnapshot("after_add_liquidity_one_coin", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.exchange_diff(0, 1, 2000 * WAD, RAY / 2 / 10 ** 12))
            );
            comparator.takeSnapshot("after_exchange_diff", creditAccount);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(pool.add_diff_liquidity_one_coin(100 * 10 ** 6, 1, (RAY * 10 ** 12) / 2))
            );
            comparator.takeSnapshot("after_add_diff_liquidity_one_coin", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.remove_diff_liquidity_one_coin(100 * WAD, 0, RAY / 2))
            );
            comparator.takeSnapshot("after_remove_diff_liquidity_one_coin", creditAccount);

            vm.stopPrank();
        } else {
            ICurvePool3Assets pool = ICurvePool3Assets(curvePoolAddr);

            vm.startPrank(creditAccount);

            pool.exchange(int128(0), 2, 2000 * WAD, 1500 * (10 ** 6));
            comparator.takeSnapshot("after_exchange", creditAccount);

            uint256[3] memory amounts = [1000 * WAD, 0, 1000 * (10 ** 6)];

            pool.add_liquidity(amounts, 0);
            comparator.takeSnapshot("after_add_liquidity", creditAccount);

            amounts = [uint256(0), 0, 0];

            pool.remove_liquidity(500 * WAD, amounts);
            comparator.takeSnapshot("after_remove_liquidity", creditAccount);

            pool.remove_liquidity_one_coin(500 * WAD, int128(1), 0);
            comparator.takeSnapshot("after_remove_liquidity_one_coin", creditAccount);

            amounts = [500 * WAD, 0, 100 * (10 ** 6)];

            pool.remove_liquidity_imbalance(amounts, type(uint256).max);
            comparator.takeSnapshot("after_remove_liquidity_imbalance", creditAccount);

            pool.add_liquidity([100 * WAD, 0, 0], 50 * WAD);
            comparator.takeSnapshot("after_add_liquidity_one_coin", creditAccount);

            uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens.DAI, creditAccount) - 2000 * WAD;
            pool.exchange(int128(0), int128(1), balanceToSwap, balanceToSwap / (2 * 10 ** 12));
            comparator.takeSnapshot("after_exchange_diff", creditAccount);

            balanceToSwap = tokenTestSuite.balanceOf(Tokens.USDC, creditAccount) - 100 * 10 ** 6;
            pool.add_liquidity([0, balanceToSwap, 0], (balanceToSwap * 10 ** 12) / 2);
            comparator.takeSnapshot("after_add_diff_liquidity_one_coin", creditAccount);

            balanceToSwap = tokenTestSuite.balanceOf(Tokens._3Crv, creditAccount) - 100 * WAD;
            pool.remove_liquidity_one_coin(balanceToSwap, int128(0), balanceToSwap / 2);
            comparator.takeSnapshot("after_remove_diff_liquidity_one_coin", creditAccount);

            vm.stopPrank();
        }
    }

    /// @dev Opens credit account for USER and make amount of desired token equal
    /// amounts for USER and CA to be able to launch test for both
    function openCreditAccountWithDai(uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);
        tokenTestSuite.mint(Tokens.DAI, creditAccount, amount);
    }

    /// @dev [L-CRVET-1]: 3CRV adapter and normal account works identically
    function test_live_CRVET_01_3CRV_adapter_and_normal_account_works_identically() public liveTest {
        address creditAccount = openCreditAccountWithDai(10000 * WAD);

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.DAI), creditAccount, supportedContracts.addressOf(Contracts.CURVE_3CRV_POOL)
        );

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.USDC),
            creditAccount,
            supportedContracts.addressOf(Contracts.CURVE_3CRV_POOL)
        );

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.USDT),
            creditAccount,
            supportedContracts.addressOf(Contracts.CURVE_3CRV_POOL)
        );

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens._3Crv),
            creditAccount,
            supportedContracts.addressOf(Contracts.CURVE_3CRV_POOL)
        );

        uint256 snapshot = vm.snapshot();

        compareBehavior(creditAccount, supportedContracts.addressOf(Contracts.CURVE_3CRV_POOL), false);

        /// Stores save balances in memory, because all state data would be reverted afer snapshot
        BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

        vm.revertTo(snapshot);

        compareBehavior(creditAccount, getAdapter(address(creditManager), Contracts.CURVE_3CRV_POOL), true);

        comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
    }
}
