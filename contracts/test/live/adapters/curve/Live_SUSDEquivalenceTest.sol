// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
// import {ICurvePool4Assets} from "../../../../integrations/curve/ICurvePool_4.sol";
// import {ICurveV1_4AssetsAdapter} from "../../../../interfaces/curve/ICurveV1_4AssetsAdapter.sol";

// import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";
// import {Contracts} from "@gearbox-protocol/sdk/contracts/SupportedContracts.sol";

// import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
// import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
// // TEST
// import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// // SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
// import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_CurveSusdEquivalenceTest is LiveTestHelper {
// using CreditFacadeV3Calls for CreditFacadeV3Multicaller;
// using CurveV1Calls for CurveV1Multicaller;

// BalanceComparator comparator;

// function setUp() public liveTest {
//     _setUp();

//     // TOKENS TO TRACK ["crvPlain3andSUSD", "DAI", "USDC", "USDT", "sUSD"]
//     Tokens[5] memory tokensToTrack = [Tokens.crvPlain3andSUSD, Tokens.DAI, Tokens.USDC, Tokens.USDT, Tokens.sUSD];

//     // STAGES
//     string[9] memory stages = [
//         "after_exchange",
//         "after_add_liquidity",
//         "after_remove_liquidity",
//         "after_remove_liquidity_one_coin",
//         "after_remove_liquidity_imbalance",
//         "after_add_liquidity_one_coin",
//         "after_exchange_all",
//         "after_add_all_liquidity_one_coin",
//         "after_remove_all_liquidity_one_coin"
//     ];

//     /// @notice Sets comparator for this equivalence test

//     uint256 len = stages.length;
//     string[] memory _stages = new string[](len);
//     unchecked {
//         for (uint256 i; i < len; ++i) {
//             _stages[i] = stages[i];
//         }
//     }

//     len = tokensToTrack.length;
//     Tokens[] memory _tokensToTrack = new Tokens[](len);
//     unchecked {
//         for (uint256 i; i < len; ++i) {
//             _tokensToTrack[i] = tokensToTrack[i];
//         }
//     }

//     comparator = new BalanceComparator(
//         _stages,
//         _tokensToTrack,
//         tokenTestSuite
//     );

//     tokenTestSuite.approveMany(_tokensToTrack, USER, supportedContracts.addressOf(Contracts.CURVE_SUSD_POOL));

//     tokenTestSuite.approveMany(_tokensToTrack, USER, supportedContracts.addressOf(Contracts.CURVE_SUSD_DEPOSIT));
// }

// /// HELPER

// function compareBehavior(
//     address curvePoolAddr,
//     address curveDepositAddr,
//     address accountToSaveBalances,
//     bool isAdapter
// ) internal {
//     if (isAdapter) {
//         ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.DAI);
//         CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);
//         CurveV1Multicaller deposit = CurveV1Multicaller(curveDepositAddr);

//         vm.prank(USER);
//         creditFacade.multicall(
//             MultiCallBuilder.build(pool.exchange(int128(0), int128(1), 2000 * WAD, 1500 * (10 ** 6)))
//         );
//         comparator.takeSnapshot("after_exchange", accountToSaveBalances);

//         uint256[4] memory amounts = [1000 * WAD, 1000 * (10 ** 6), 0, 0];

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.add_liquidity(amounts, 0)));
//         comparator.takeSnapshot("after_add_liquidity", accountToSaveBalances);

//         amounts = [uint256(0), 0, 0, 0];

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.remove_liquidity(500 * WAD, amounts)));
//         comparator.takeSnapshot("after_remove_liquidity", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(deposit.remove_liquidity_one_coin(500 * WAD, int128(1), 0)));
//         comparator.takeSnapshot("after_remove_liquidity_one_coin", accountToSaveBalances);

//         amounts = [500 * WAD, 100 * (10 ** 6), 0, 0];

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.remove_liquidity_imbalance(amounts, type(uint256).max)));
//         comparator.takeSnapshot("after_remove_liquidity_imbalance", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.add_liquidity_one_coin(100 * WAD, int128(0), 50 * WAD)));
//         comparator.takeSnapshot("after_add_liquidity_one_coin", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.exchange_all(int128(0), int128(1), RAY / 2 / 10 ** 12)));
//         comparator.takeSnapshot("after_exchange_all", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(
//             MultiCallBuilder.build(pool.add_all_liquidity_one_coin(int128(1), (RAY * 10 ** 12) / 2))
//         );
//         comparator.takeSnapshot("after_add_all_liquidity_one_coin", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(deposit.remove_all_liquidity_one_coin(int128(0), RAY / 2)));
//         comparator.takeSnapshot("after_remove_all_liquidity_one_coin", accountToSaveBalances);
//     } else {
//         ICurvePool4Assets pool = ICurvePool4Assets(curvePoolAddr);
//         ICurvePool4Assets deposit = ICurvePool4Assets(curveDepositAddr);

//         vm.prank(USER);
//         pool.exchange(int128(0), int128(1), 2000 * WAD, 1500 * (10 ** 6));
//         comparator.takeSnapshot("after_exchange", accountToSaveBalances);

//         uint256[4] memory amounts = [1000 * WAD, 1000 * (10 ** 6), 0, 0];

//         vm.prank(USER);
//         pool.add_liquidity(amounts, 0);
//         comparator.takeSnapshot("after_add_liquidity", accountToSaveBalances);

//         amounts = [uint256(0), 0, 0, 0];

//         vm.prank(USER);
//         pool.remove_liquidity(500 * WAD, amounts);
//         comparator.takeSnapshot("after_remove_liquidity", accountToSaveBalances);

//         vm.prank(USER);
//         deposit.remove_liquidity_one_coin(500 * WAD, int128(1), 0);
//         comparator.takeSnapshot("after_remove_liquidity_one_coin", accountToSaveBalances);

//         amounts = [500 * WAD, 100 * (10 ** 6), 0, 0];

//         vm.prank(USER);
//         pool.remove_liquidity_imbalance(amounts, type(uint256).max);
//         comparator.takeSnapshot("after_remove_liquidity_imbalance", accountToSaveBalances);

//         vm.prank(USER);
//         pool.add_liquidity([100 * WAD, 0, 0, 0], 50 * WAD);
//         comparator.takeSnapshot("after_add_liquidity_one_coin", accountToSaveBalances);

//         uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens.DAI, accountToSaveBalances) - 1;
//         vm.prank(USER);
//         pool.exchange(int128(0), int128(1), balanceToSwap, balanceToSwap / (2 * 10 ** 12));
//         comparator.takeSnapshot("after_exchange_all", accountToSaveBalances);

//         balanceToSwap = tokenTestSuite.balanceOf(Tokens.USDC, accountToSaveBalances) - 1;
//         vm.prank(USER);
//         pool.add_liquidity([0, balanceToSwap, 0, 0], (balanceToSwap * 10 ** 12) / 2);
//         comparator.takeSnapshot("after_add_all_liquidity_one_coin", accountToSaveBalances);

//         balanceToSwap = tokenTestSuite.balanceOf(Tokens.crvPlain3andSUSD, accountToSaveBalances) - 1;
//         vm.prank(USER);
//         deposit.remove_liquidity_one_coin(balanceToSwap, int128(0), balanceToSwap / 2);
//         comparator.takeSnapshot("after_remove_all_liquidity_one_coin", accountToSaveBalances);
//     }
// }

// /// @dev Opens credit account for USER and make amount of desired token equal
// /// amounts for USER and CA to be able to launch test for both
// function openCreditAccountWithEqualAmount(uint256 amount) internal returns (address creditAccount) {
//     ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.DAI);

//     tokenTestSuite.mint(Tokens.DAI, USER, 3 * amount);

//     // Approve tokens
//     tokenTestSuite.approve(Tokens.DAI, USER, address(lts.CreditManagerV3s(Tokens.DAI)));

//     vm.startPrank(USER);
//     creditFacade.openCreditAccountMulticall(
//         amount,
//         USER,
//         MultiCallBuilder.build(
//             CreditFacadeV3Multicaller(address(creditFacade)).addCollateral(
//                 USER, tokenTestSuite.addressOf(Tokens.DAI), amount
//             )
//         ),
//         0
//     );

//     vm.stopPrank();

//     creditAccount = lts.CreditManagerV3s(Tokens.DAI).getCreditAccountOrRevert(USER);
// }

// /// @dev [L-CRVET-7]: Curve SUSD adapter and normal account works identically
// function test_live_CRVET_07_SUSD_adapter_and_normal_account_works_identically() public liveTest {
//     ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.DAI);

//     (uint256 minAmount,) = creditFacade.limits();

//     address creditAccount = openCreditAccountWithEqualAmount(minAmount);

//     uint256 snapshot = vm.snapshot();

//     compareBehavior(
//         supportedContracts.addressOf(Contracts.CURVE_SUSD_POOL),
//         supportedContracts.addressOf(Contracts.CURVE_SUSD_DEPOSIT),
//         USER,
//         false
//     );

//     /// Stores save balances in memory, because all state data would be reverted afer snapshot
//     BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(USER);

//     vm.revertTo(snapshot);

//     compareBehavior(
//         getAdapter(Tokens.DAI, Contracts.CURVE_SUSD_POOL),
//         getAdapter(Tokens.DAI, Contracts.CURVE_SUSD_DEPOSIT),
//         creditAccount,
//         true
//     );

//     comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
// }
}
