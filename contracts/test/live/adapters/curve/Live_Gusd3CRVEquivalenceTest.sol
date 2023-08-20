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

contract Live_CurveGusdEquivalenceTest is LiveTestHelper {
// using CreditFacadeV3Calls for CreditFacadeV3Multicaller;
// using CurveV1Calls for CurveV1Multicaller;

// BalanceComparator comparator;

// string[] _stages;

// function setUp() public liveTest {
//     _setUp();

//     // STAGES
//     string[11] memory stages = [
//         "after_exchange",
//         "after_exchange_underlying",
//         "after_add_liquidity",
//         "after_remove_liquidity",
//         "after_remove_liquidity_one_coin",
//         "after_remove_liquidity_imbalance",
//         "after_add_liquidity_one_coin",
//         "after_exchange_all",
//         "after_add_all_liquidity_one_coin",
//         "after_remove_all_liquidity_one_coin",
//         "after_exchange_all_underlying"
//     ];

//     /// @notice Sets comparator for this equivalence test

//     uint256 len = stages.length;
//     _stages = new string[](len);
//     unchecked {
//         for (uint256 i; i < len; ++i) {
//             _stages[i] = stages[i];
//         }
//     }
// }

// /// HELPER

// function compareBehavior(address curvePoolAddr, address accountToSaveBalances, bool isAdapter) internal {
//     if (isAdapter) {
//         ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.DAI);
//         CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.exchange(int128(1), int128(0), 3000 * WAD, 2000 * 100)));
//         comparator.takeSnapshot("after_exchange", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(
//             MultiCallBuilder.build(pool.exchange_underlying(int128(0), int128(2), 500 * 100, 125 * (10 ** 6)))
//         );
//         comparator.takeSnapshot("after_exchange_underlying", accountToSaveBalances);

//         uint256[2] memory amounts = [1500 * 100, 1500 * WAD];

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.add_liquidity(amounts, 0)));
//         comparator.takeSnapshot("after_add_liquidity", accountToSaveBalances);

//         amounts = [uint256(0), 0];

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.remove_liquidity(500 * WAD, amounts)));
//         comparator.takeSnapshot("after_remove_liquidity", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.remove_liquidity_one_coin(500 * WAD, int128(1), 0)));
//         comparator.takeSnapshot("after_remove_liquidity_one_coin", accountToSaveBalances);

//         amounts = [100 * 100, 500 * WAD];

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.remove_liquidity_imbalance(amounts, type(uint256).max)));
//         comparator.takeSnapshot("after_remove_liquidity_imbalance", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.add_liquidity_one_coin(100 * WAD, int128(1), 50 * WAD)));
//         comparator.takeSnapshot("after_add_liquidity_one_coin", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(pool.exchange_all(int128(1), int128(0), RAY / 2 / 10 ** 16)));
//         comparator.takeSnapshot("after_exchange_all", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(
//             MultiCallBuilder.build(pool.add_all_liquidity_one_coin(int128(0), (RAY * 10 ** 16) / 2))
//         );
//         comparator.takeSnapshot("after_add_all_liquidity_one_coin", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(
//             MultiCallBuilder.build(pool.remove_all_liquidity_one_coin(int128(0), RAY / 2 / 10 ** 16))
//         );
//         comparator.takeSnapshot("after_remove_all_liquidity_one_coin", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(
//             MultiCallBuilder.build(pool.exchange_all_underlying(int128(0), int128(2), (RAY * 10 ** 4) / 2))
//         );
//         comparator.takeSnapshot("after_exchange_all_underlying", accountToSaveBalances);
//     } else {
//         ICurvePool2Assets pool = ICurvePool2Assets(curvePoolAddr);

//         vm.prank(USER);
//         pool.exchange(int128(1), int128(0), 3000 * WAD, 2000 * 100);
//         comparator.takeSnapshot("after_exchange", accountToSaveBalances);

//         vm.prank(USER);
//         pool.exchange_underlying(int128(0), int128(2), 500 * 100, 125 * (10 ** 6));
//         comparator.takeSnapshot("after_exchange_underlying", accountToSaveBalances);

//         uint256[2] memory amounts = [1500 * 100, 1500 * WAD];

//         vm.prank(USER);
//         pool.add_liquidity(amounts, 0);
//         comparator.takeSnapshot("after_add_liquidity", accountToSaveBalances);

//         amounts = [uint256(0), 0];

//         vm.prank(USER);
//         pool.remove_liquidity(500 * WAD, amounts);
//         comparator.takeSnapshot("after_remove_liquidity", accountToSaveBalances);

//         vm.prank(USER);
//         pool.remove_liquidity_one_coin(500 * WAD, int128(1), 0);
//         comparator.takeSnapshot("after_remove_liquidity_one_coin", accountToSaveBalances);

//         amounts = [100 * 100, 500 * WAD];

//         vm.prank(USER);
//         pool.remove_liquidity_imbalance(amounts, type(uint256).max);
//         comparator.takeSnapshot("after_remove_liquidity_imbalance", accountToSaveBalances);

//         vm.prank(USER);
//         pool.add_liquidity([0, 100 * WAD], 50 * WAD);
//         comparator.takeSnapshot("after_add_liquidity_one_coin", accountToSaveBalances);

//         uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens._3Crv, accountToSaveBalances) - 1;
//         vm.prank(USER);
//         pool.exchange(int128(1), int128(0), balanceToSwap, balanceToSwap / (2 * 10 ** 16));
//         comparator.takeSnapshot("after_exchange_all", accountToSaveBalances);

//         balanceToSwap = tokenTestSuite.balanceOf(Tokens.GUSD, accountToSaveBalances) - 1;
//         vm.prank(USER);
//         pool.add_liquidity([balanceToSwap, 0], (balanceToSwap * 10 ** 16) / 2);
//         comparator.takeSnapshot("after_add_all_liquidity_one_coin", accountToSaveBalances);

//         balanceToSwap = tokenTestSuite.balanceOf(Tokens.gusd3CRV, accountToSaveBalances) - 1;
//         vm.prank(USER);
//         pool.remove_liquidity_one_coin(balanceToSwap, int128(0), balanceToSwap / (2 * 10 ** 16));
//         comparator.takeSnapshot("after_remove_all_liquidity_one_coin", accountToSaveBalances);
//         balanceToSwap = tokenTestSuite.balanceOf(Tokens.GUSD, accountToSaveBalances) - 1;
//         vm.prank(USER);
//         pool.exchange_underlying(int128(0), int128(2), balanceToSwap, (balanceToSwap * 10 ** 4) / 2);
//         comparator.takeSnapshot("after_exchange_all_underlying", accountToSaveBalances);
//     }
// }

// /// @dev Opens credit account for USER and make amount of desired token equal
// /// amounts for USER and CA to be able to launch test for both
// function openEquivalentCreditAccountWith3CRVAmount(uint256 amount) internal returns (address creditAccount) {
//     ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.DAI);

//     (uint256 minAmount,) = creditFacade.limits();

//     tokenTestSuite.mint(Tokens.DAI, USER, 3 * minAmount);

//     tokenTestSuite.mint(Tokens._3Crv, USER, 2 * amount);

//     // Approve tokens
//     tokenTestSuite.approve(Tokens.DAI, USER, address(lts.CreditManagerV3s(Tokens.DAI)));

//     tokenTestSuite.approve(Tokens._3Crv, USER, address(lts.CreditManagerV3s(Tokens.DAI)));

//     vm.startPrank(USER);
//     creditFacade.openCreditAccountMulticall(
//         minAmount,
//         USER,
//         MultiCallBuilder.build(
//             CreditFacadeV3Multicaller(address(creditFacade)).addCollateral(
//                 USER, tokenTestSuite.addressOf(Tokens.DAI), minAmount
//             ),
//             CreditFacadeV3Multicaller(address(creditFacade)).addCollateral(
//                 USER, tokenTestSuite.addressOf(Tokens._3Crv), amount
//             )
//         ),
//         0
//     );

//     vm.stopPrank();

//     creditAccount = lts.CreditManagerV3s(Tokens.DAI).getCreditAccountOrRevert(USER);
// }

// /// @dev [L-CRVET-4]: gusd3CRV adapter and normal account works identically
// function test_live_CRVET_04_gusd3CRV_adapter_and_normal_account_works_identically() public liveTest {
//     Tokens[6] memory tokensToTrack =
//         [Tokens.GUSD, Tokens._3Crv, Tokens.DAI, Tokens.USDC, Tokens.USDT, Tokens.gusd3CRV];

//     uint256 len = tokensToTrack.length;
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
//     tokenTestSuite.approveMany(_tokensToTrack, USER, supportedContracts.addressOf(Contracts.CURVE_GUSD_POOL));

//     address creditAccount = openEquivalentCreditAccountWith3CRVAmount(5000 * WAD);

//     uint256 snapshot = vm.snapshot();

//     compareBehavior(supportedContracts.addressOf(Contracts.CURVE_GUSD_POOL), USER, false);

//     /// Stores save balances in memory, because all state data would be reverted afer snapshot
//     BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(USER);

//     vm.revertTo(snapshot);

//     compareBehavior(getAdapter(Tokens.DAI, Contracts.CURVE_GUSD_POOL), creditAccount, true);

//     comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
// }
}
