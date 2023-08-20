// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
// import {ICurvePool2Assets} from "../../../../integrations/curve/ICurvePool_2.sol";
// import {ICurveV1_2AssetsAdapter} from "../../../../interfaces/curve/ICurveV1_2AssetsAdapter.sol";

// import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";
// import {Contracts} from "@gearbox-protocol/sdk/contracts/SupportedContracts.sol";

// import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
// import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
// // TEST
// import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// // SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
// import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_CurveStETHEquivalenceTest is LiveTestHelper {
// using CreditFacadeV3Calls for CreditFacadeV3Multicaller;
// using CurveV1Calls for CurveV1Multicaller;

// BalanceComparator comparator;

// function setUp() public liveTest {
//     _setUp();

//     // TOKENS TO TRACK ["crvFRAX", "FRAX", "USDC"]
//     Tokens[3] memory tokensToTrack = [Tokens.steCRV, Tokens.WETH, Tokens.STETH];

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

//     /// @notice Approves all tracked tokens for USER
//     tokenTestSuite.approveMany(_tokensToTrack, USER, supportedContracts.addressOf(Contracts.CURVE_STETH_GATEWAY));
// }

// /// HELPER

// function compareBehavior(address curvePoolAddr, address accountToSaveBalances, bool isAdapter) internal {
//     if (isAdapter) {
//         ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.WETH);
//         CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.exchange(int128(0), int128(1), 5 * WAD, WAD)));
//         comparator.takeSnapshot("after_exchange", accountToSaveBalances);

//         uint256[2] memory amounts = [4 * WAD, 4 * WAD];

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.add_liquidity(amounts, 0)));
//         comparator.takeSnapshot("after_add_liquidity", accountToSaveBalances);

//         amounts = [uint256(0), 0];

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.remove_liquidity(WAD, amounts)));
//         comparator.takeSnapshot("after_remove_liquidity", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.remove_liquidity_one_coin(WAD, int128(1), 0)));
//         comparator.takeSnapshot("after_remove_liquidity_one_coin", accountToSaveBalances);

//         amounts = [WAD, WAD / 5];

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.remove_liquidity_imbalance(amounts, 2 * WAD)));
//         comparator.takeSnapshot("after_remove_liquidity_imbalance", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.add_liquidity_one_coin(WAD, int128(0), WAD / 2)));
//         comparator.takeSnapshot("after_add_liquidity_one_coin", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.exchange_all(int128(0), int128(1), RAY / 2)));
//         comparator.takeSnapshot("after_exchange_all", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.add_all_liquidity_one_coin(int128(1), RAY / 2)));
//         comparator.takeSnapshot("after_add_all_liquidity_one_coin", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.remove_all_liquidity_one_coin(int128(0), RAY / 2)));
//         comparator.takeSnapshot("after_remove_all_liquidity_one_coin", accountToSaveBalances);
//     } else {
//         ICurvePool2Assets pool = ICurvePool2Assets(curvePoolAddr);

//         vm.prank(USER);
//         pool.exchange(int128(0), int128(1), 5 * WAD, WAD);
//         comparator.takeSnapshot("after_exchange", accountToSaveBalances);

//         uint256[2] memory amounts = [4 * WAD, 4 * WAD];

//         vm.prank(USER);
//         pool.add_liquidity(amounts, 0);
//         comparator.takeSnapshot("after_add_liquidity", accountToSaveBalances);

//         amounts = [uint256(0), 0];

//         vm.prank(USER);
//         pool.remove_liquidity(WAD, amounts);
//         comparator.takeSnapshot("after_remove_liquidity", accountToSaveBalances);

//         vm.prank(USER);
//         pool.remove_liquidity_one_coin(WAD, int128(1), 0);
//         comparator.takeSnapshot("after_remove_liquidity_one_coin", accountToSaveBalances);

//         amounts = [WAD, WAD / 5];

//         vm.prank(USER);
//         pool.remove_liquidity_imbalance(amounts, 2 * WAD);
//         comparator.takeSnapshot("after_remove_liquidity_imbalance", accountToSaveBalances);

//         vm.prank(USER);
//         pool.add_liquidity([WAD, 0], WAD / 2);
//         comparator.takeSnapshot("after_add_liquidity_one_coin", accountToSaveBalances);

//         uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens.WETH, accountToSaveBalances) - 1;
//         vm.prank(USER);
//         pool.exchange(int128(0), int128(1), balanceToSwap, balanceToSwap / 2);
//         comparator.takeSnapshot("after_exchange_all", accountToSaveBalances);

//         balanceToSwap = tokenTestSuite.balanceOf(Tokens.STETH, accountToSaveBalances) - 1;
//         vm.prank(USER);
//         pool.add_liquidity([0, balanceToSwap], balanceToSwap / 2);
//         comparator.takeSnapshot("after_add_all_liquidity_one_coin", accountToSaveBalances);

//         balanceToSwap = tokenTestSuite.balanceOf(Tokens.steCRV, accountToSaveBalances) - 1;
//         vm.prank(USER);
//         pool.remove_liquidity_one_coin(balanceToSwap, int128(0), balanceToSwap / 2);
//         comparator.takeSnapshot("after_remove_all_liquidity_one_coin", accountToSaveBalances);
//     }
// }

// /// @dev Opens credit account for USER and make amount of desired token equal
// /// amounts for USER and CA to be able to launch test for both
// function openCreditAccountWithEqualAmount(uint256 amount) internal returns (address creditAccount) {
//     ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.WETH);

//     tokenTestSuite.mint(Tokens.WETH, USER, 3 * amount);

//     // Approve tokens
//     tokenTestSuite.approve(Tokens.WETH, USER, address(lts.CreditManagerV3s(Tokens.WETH)));

//     vm.startPrank(USER);
//     creditFacade.openCreditAccountMulticall(
//         amount,
//         USER,
//         MultiCallBuilder.build(
//             CreditFacadeV3Multicaller(address(creditFacade)).addCollateral(
//                 USER, tokenTestSuite.addressOf(Tokens.WETH), amount
//             )
//         ),
//         0
//     );

//     vm.stopPrank();

//     creditAccount = lts.CreditManagerV3s(Tokens.WETH).getCreditAccountOrRevert(USER);
// }

// /// @dev [L-CRVET-6]: stETH adapter and normal account works identically
// function test_live_CRVET_06_stETH_adapter_and_normal_account_works_identically() public liveTest {
//     ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.WETH);

//     (uint256 minAmount,) = creditFacade.limits();

//     address creditAccount = openCreditAccountWithEqualAmount(minAmount);

//     uint256 snapshot = vm.snapshot();

//     compareBehavior(supportedContracts.addressOf(Contracts.CURVE_STETH_GATEWAY), USER, false);

//     /// Stores save balances in memory, because all state data would be reverted afer snapshot
//     BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(USER);

//     vm.revertTo(snapshot);

//     compareBehavior(getAdapter(Tokens.WETH, Contracts.CURVE_STETH_GATEWAY), creditAccount, true);

//     comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
// }
}
