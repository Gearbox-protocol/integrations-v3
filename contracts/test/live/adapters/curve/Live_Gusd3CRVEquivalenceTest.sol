// // SPDX-License-Identifier: UNLICENSED
// // Gearbox Protocol. Generalized leverage for DeFi protocols
// // (c) Gearbox Foundation, 2023.
// pragma solidity ^0.8.17;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
// import {ICurvePool2Assets} from "../../../../integrations/curve/ICurvePool_2.sol";
// import {ICurveV1_2AssetsAdapter} from "../../../../interfaces/curve/ICurveV1_2AssetsAdapter.sol";

// import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
// import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

// import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
// import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";

// import {CurveV1Calls, CurveV1Multicaller} from "../../../multicall/curve/CurveV1_Calls.sol";
// // TEST
// import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// // SUITES

// import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
// import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

// contract Live_CurveGusdEquivalenceTest is LiveTestHelper {
//     using CurveV1Calls for CurveV1Multicaller;

//     BalanceComparator comparator;

//     string[] _stages;

//     function setUp() public attachOrLiveTest {
//         _setUp();

//         // STAGES
//         string[11] memory stages = [
//             "after_exchange",
//             "after_exchange_underlying",
//             "after_add_liquidity",
//             "after_remove_liquidity",
//             "after_remove_liquidity_one_coin",
//             "after_remove_liquidity_imbalance",
//             "after_add_liquidity_one_coin",
//             "after_exchange_diff",
//             "after_add_diff_liquidity_one_coin",
//             "after_remove_diff_liquidity_one_coin",
//             "after_exchange_diff_underlying"
//         ];

//         /// @notice Sets comparator for this equivalence test

//         uint256 len = stages.length;
//         _stages = new string[](len);
//         unchecked {
//             for (uint256 i; i < len; ++i) {
//                 _stages[i] = stages[i];
//             }
//         }
//     }

//     /// HELPER

//     function compareBehavior(address creditAccount, address curvePoolAddr, bool isAdapter) internal {
//         if (isAdapter) {
//             CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);

//             vm.startPrank(USER);

//             creditFacade.multicall(
//                 creditAccount, MultiCallBuilder.build(pool.exchange(int128(1), int128(0), 3000 * WAD, 2000 * 100))
//             );
//             comparator.takeSnapshot("after_exchange", creditAccount);

//             creditFacade.multicall(
//                 creditAccount,
//                 MultiCallBuilder.build(pool.exchange_underlying(int128(0), int128(2), 500 * 100, 125 * (10 ** 6)))
//             );
//             comparator.takeSnapshot("after_exchange_underlying", creditAccount);

//             uint256[2] memory amounts = [1500 * 100, 1500 * WAD];

//             creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.add_liquidity(amounts, 0)));
//             comparator.takeSnapshot("after_add_liquidity", creditAccount);

//             amounts = [uint256(0), 0];

//             creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.remove_liquidity(500 * WAD, amounts)));
//             comparator.takeSnapshot("after_remove_liquidity", creditAccount);

//             creditFacade.multicall(
//                 creditAccount, MultiCallBuilder.build(pool.remove_liquidity_one_coin(500 * WAD, int128(1), 0))
//             );
//             comparator.takeSnapshot("after_remove_liquidity_one_coin", creditAccount);

//             amounts = [100 * 100, 500 * WAD];

//             creditFacade.multicall(
//                 creditAccount, MultiCallBuilder.build(pool.remove_liquidity_imbalance(amounts, type(uint256).max))
//             );
//             comparator.takeSnapshot("after_remove_liquidity_imbalance", creditAccount);

//             creditFacade.multicall(
//                 creditAccount, MultiCallBuilder.build(pool.add_liquidity_one_coin(100 * WAD, 1, 50 * WAD))
//             );
//             comparator.takeSnapshot("after_add_liquidity_one_coin", creditAccount);

//             creditFacade.multicall(
//                 creditAccount, MultiCallBuilder.build(pool.exchange_diff(100 * WAD, 1, 0, RAY / 2 / 10 ** 16))
//             );
//             comparator.takeSnapshot("after_exchange_diff", creditAccount);

//             creditFacade.multicall(
//                 creditAccount,
//                 MultiCallBuilder.build(pool.add_diff_liquidity_one_coin(100 * 10 ** 2, 0, (RAY * 10 ** 16) / 2))
//             );
//             comparator.takeSnapshot("after_add_diff_liquidity_one_coin", creditAccount);

//             creditFacade.multicall(
//                 creditAccount,
//                 MultiCallBuilder.build(pool.remove_diff_liquidity_one_coin(100 * WAD, 0, RAY / 2 / 10 ** 16))
//             );
//             comparator.takeSnapshot("after_remove_diff_liquidity_one_coin", creditAccount);

//             creditFacade.multicall(
//                 creditAccount,
//                 MultiCallBuilder.build(pool.exchange_diff_underlying(100 * 10 ** 2, 0, 2, (RAY * 10 ** 4) / 2))
//             );
//             comparator.takeSnapshot("after_exchange_diff_underlying", creditAccount);

//             vm.stopPrank();
//         } else {
//             ICurvePool2Assets pool = ICurvePool2Assets(curvePoolAddr);

//             vm.startPrank(creditAccount);

//             pool.exchange(int128(1), int128(0), 3000 * WAD, 2000 * 100);
//             comparator.takeSnapshot("after_exchange", creditAccount);

//             pool.exchange_underlying(int128(0), int128(2), 500 * 100, 125 * (10 ** 6));
//             comparator.takeSnapshot("after_exchange_underlying", creditAccount);

//             uint256[2] memory amounts = [1500 * 100, 1500 * WAD];

//             pool.add_liquidity(amounts, 0);
//             comparator.takeSnapshot("after_add_liquidity", creditAccount);

//             amounts = [uint256(0), 0];

//             pool.remove_liquidity(500 * WAD, amounts);
//             comparator.takeSnapshot("after_remove_liquidity", creditAccount);

//             pool.remove_liquidity_one_coin(500 * WAD, int128(1), 0);
//             comparator.takeSnapshot("after_remove_liquidity_one_coin", creditAccount);

//             amounts = [100 * 100, 500 * WAD];

//             pool.remove_liquidity_imbalance(amounts, type(uint256).max);
//             comparator.takeSnapshot("after_remove_liquidity_imbalance", creditAccount);

//             pool.add_liquidity([0, 100 * WAD], 50 * WAD);
//             comparator.takeSnapshot("after_add_liquidity_one_coin", creditAccount);

//             uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens._3Crv, creditAccount) - 100 * WAD;
//             pool.exchange(int128(1), int128(0), balanceToSwap, balanceToSwap / (2 * 10 ** 16));
//             comparator.takeSnapshot("after_exchange_diff", creditAccount);

//             balanceToSwap = tokenTestSuite.balanceOf(Tokens.GUSD, creditAccount) - 100 * 10 ** 2;
//             pool.add_liquidity([balanceToSwap, 0], (balanceToSwap * 10 ** 16) / 2);
//             comparator.takeSnapshot("after_add_diff_liquidity_one_coin", creditAccount);

//             balanceToSwap = tokenTestSuite.balanceOf(Tokens.gusd3CRV, creditAccount) - 100 * WAD;
//             pool.remove_liquidity_one_coin(balanceToSwap, int128(0), balanceToSwap / (2 * 10 ** 16));
//             comparator.takeSnapshot("after_remove_diff_liquidity_one_coin", creditAccount);

//             balanceToSwap = tokenTestSuite.balanceOf(Tokens.GUSD, creditAccount) - 100 * 10 ** 2;
//             pool.exchange_underlying(int128(0), int128(2), balanceToSwap, (balanceToSwap * 10 ** 4) / 2);
//             comparator.takeSnapshot("after_exchange_diff_underlying", creditAccount);

//             vm.stopPrank();
//         }
//     }

//     /// @dev Opens credit account for USER and make amount of desired token equal
//     /// amounts for USER and CA to be able to launch test for both
//     function openCreditAccountWith3CRV(uint256 amount) internal returns (address creditAccount) {
//         vm.prank(USER);
//         creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);
//         tokenTestSuite.mint(Tokens._3Crv, creditAccount, amount);
//     }

//     /// @dev [L-CRVET-4]: gusd3Crv adapter and normal account works identically
//     function test_live_CRVET_04_gusd3Crv_adapter_and_normal_account_works_identically() public {
//         address creditAccount = openCreditAccountWith3CRV(10000 * WAD);

//         tokenTestSuite.approve(
//             tokenTestSuite.addressOf(Tokens.GUSD),
//             creditAccount,
//             supportedContracts.addressOf(Contracts.CURVE_GUSD_POOL)
//         );

//         tokenTestSuite.approve(
//             tokenTestSuite.addressOf(Tokens._3Crv),
//             creditAccount,
//             supportedContracts.addressOf(Contracts.CURVE_GUSD_POOL)
//         );

//         tokenTestSuite.approve(
//             tokenTestSuite.addressOf(Tokens.gusd3CRV),
//             creditAccount,
//             supportedContracts.addressOf(Contracts.CURVE_GUSD_POOL)
//         );

//         uint256 snapshot = vm.snapshot();

//         compareBehavior(creditAccount, supportedContracts.addressOf(Contracts.CURVE_GUSD_POOL), false);

//         /// Stores save balances in memory, because all state data would be reverted afer snapshot
//         BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

//         vm.revertTo(snapshot);

//         compareBehavior(creditAccount, getAdapter(address(creditManager), Contracts.CURVE_GUSD_POOL), true);

//         comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
//     }
// }
