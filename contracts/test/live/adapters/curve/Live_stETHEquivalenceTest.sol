// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICurvePool2Assets} from "../../../../integrations/curve/ICurvePool_2.sol";
import {ICurveV1_2AssetsAdapter} from "../../../../interfaces/curve/ICurveV1_2AssetsAdapter.sol";
import {CurveV1Calls, CurveV1Multicaller} from "../../../multicall/curve/CurveV1_Calls.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_CurveStETHEquivalenceTest is LiveTestHelper {
    using CurveV1Calls for CurveV1Multicaller;

    BalanceComparator comparator;

    function setUp() public attachOrLiveTest {
        _setUp();

        Tokens[3] memory tokensToTrack = [Tokens.steCRV, Tokens.WETH, Tokens.STETH];

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
                creditAccount, MultiCallBuilder.build(pool.exchange(int128(0), int128(1), 5 * WAD, WAD))
            );
            comparator.takeSnapshot("after_exchange", creditAccount);

            uint256[2] memory amounts = [4 * WAD, 4 * WAD];

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.add_liquidity(amounts, 0)));
            comparator.takeSnapshot("after_add_liquidity", creditAccount);

            amounts = [uint256(0), 0];

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.remove_liquidity(WAD, amounts)));
            comparator.takeSnapshot("after_remove_liquidity", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.remove_liquidity_one_coin(WAD, int128(1), 0))
            );
            comparator.takeSnapshot("after_remove_liquidity_one_coin", creditAccount);

            amounts = [WAD, WAD / 5];

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.remove_liquidity_imbalance(amounts, 2 * WAD))
            );
            comparator.takeSnapshot("after_remove_liquidity_imbalance", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.add_liquidity_one_coin(WAD, 0, WAD / 2)));
            comparator.takeSnapshot("after_add_liquidity_one_coin", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.exchange_diff(0, 1, 2 * WAD, RAY / 2)));
            comparator.takeSnapshot("after_exchange_diff", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.add_diff_liquidity_one_coin(2 * WAD, 1, RAY / 2))
            );
            comparator.takeSnapshot("after_add_diff_liquidity_one_coin", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.remove_diff_liquidity_one_coin(2 * WAD, 0, RAY / 2))
            );
            comparator.takeSnapshot("after_remove_diff_liquidity_one_coin", creditAccount);

            vm.stopPrank();
        } else {
            ICurvePool2Assets pool = ICurvePool2Assets(curvePoolAddr);

            vm.startPrank(creditAccount);

            pool.exchange(int128(0), int128(1), 5 * WAD, WAD);
            comparator.takeSnapshot("after_exchange", creditAccount);

            uint256[2] memory amounts = [4 * WAD, 4 * WAD];

            pool.add_liquidity(amounts, 0);
            comparator.takeSnapshot("after_add_liquidity", creditAccount);

            amounts = [uint256(0), 0];
            pool.remove_liquidity(WAD, amounts);
            comparator.takeSnapshot("after_remove_liquidity", creditAccount);

            pool.remove_liquidity_one_coin(WAD, int128(1), 0);
            comparator.takeSnapshot("after_remove_liquidity_one_coin", creditAccount);

            amounts = [WAD, WAD / 5];
            pool.remove_liquidity_imbalance(amounts, 2 * WAD);
            comparator.takeSnapshot("after_remove_liquidity_imbalance", creditAccount);

            pool.add_liquidity([WAD, 0], WAD / 2);
            comparator.takeSnapshot("after_add_liquidity_one_coin", creditAccount);

            uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens.WETH, creditAccount) - 2 * WAD;
            pool.exchange(int128(0), int128(1), balanceToSwap, balanceToSwap / 2);
            comparator.takeSnapshot("after_exchange_diff", creditAccount);

            balanceToSwap = tokenTestSuite.balanceOf(Tokens.STETH, creditAccount) - 2 * WAD;
            pool.add_liquidity([0, balanceToSwap], balanceToSwap / 2);
            comparator.takeSnapshot("after_add_diff_liquidity_one_coin", creditAccount);

            balanceToSwap = tokenTestSuite.balanceOf(Tokens.steCRV, creditAccount) - 2 * WAD;
            pool.remove_liquidity_one_coin(balanceToSwap, int128(0), balanceToSwap / 2);
            comparator.takeSnapshot("after_remove_diff_liquidity_one_coin", creditAccount);

            vm.stopPrank();
        }
    }

    /// @dev Opens credit account for USER and make amount of desired token equal
    /// amounts for USER and CA to be able to launch test for both
    function openCreditAccountWithWeth(uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);
        tokenTestSuite.mint(Tokens.WETH, creditAccount, amount);
    }

    /// @dev [L-CRVET-3]: Curve steth adapter and normal account works identically
    function test_live_CRVET_03_steth_adapter_and_normal_account_works_identically() public {
        address creditAccount = openCreditAccountWithWeth(50 * WAD);

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.WETH),
            creditAccount,
            supportedContracts.addressOf(Contracts.CURVE_STETH_GATEWAY)
        );

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.STETH),
            creditAccount,
            supportedContracts.addressOf(Contracts.CURVE_STETH_GATEWAY)
        );

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.steCRV),
            creditAccount,
            supportedContracts.addressOf(Contracts.CURVE_STETH_GATEWAY)
        );

        uint256 snapshot = vm.snapshot();

        compareBehavior(creditAccount, supportedContracts.addressOf(Contracts.CURVE_STETH_GATEWAY), false);

        /// Stores save balances in memory, because all state data would be reverted afer snapshot
        BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

        vm.revertTo(snapshot);

        compareBehavior(creditAccount, getAdapter(address(creditManager), Contracts.CURVE_STETH_GATEWAY), true);

        comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
    }
}
