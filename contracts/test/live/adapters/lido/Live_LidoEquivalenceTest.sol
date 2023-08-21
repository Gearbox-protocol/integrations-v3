// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
// import {ILidoV1Adapter} from "../../../../interfaces/lido/ILidoV1Adapter.sol";
// import {LidoV1Gateway} from "../../../../gateways/lido/LidoV1_WETHGateway.sol";

// import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
// import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

// import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
// import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
// // TEST
// import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// // SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
// import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_LidoEquivalenceTest is LiveTestHelper {
// using CreditFacadeV3Calls for CreditFacadeV3Multicaller;
// using LidoV1_Calls for LidoV1_Multicaller;

// BalanceComparator comparator;

// function setUp() public liveTest {
//     _setUp();

//     Tokens[2] memory tokensToTrack = [Tokens.WETH, Tokens.STETH];

//     // STAGES
//     string[2] memory stages = ["after_submit", "after_submitAll"];

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
//     tokenTestSuite.approveMany(_tokensToTrack, USER, supportedContracts.addressOf(Contracts.LIDO_STETH_GATEWAY));
// }

// /// HELPER

// function compareBehavior(address lidoAddr, address accountToSaveBalances, bool isAdapter) internal {
//     if (isAdapter) {
//         ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.WETH);
//         LidoV1_Multicaller lido = LidoV1_Multicaller(lidoAddr);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(lido.submit(WAD)));
//         comparator.takeSnapshot("after_submit", accountToSaveBalances);

//         vm.prank(USER);
//         creditFacade.multicall(MultiCallBuilder.build(lido.submitAll()));
//         comparator.takeSnapshot("after_submitAll", accountToSaveBalances);
//     } else {
//         LidoV1Gateway lido = LidoV1Gateway(payable(lidoAddr));

//         vm.prank(USER);
//         lido.submit(WAD, DUMB_ADDRESS);
//         comparator.takeSnapshot("after_submit", accountToSaveBalances);

//         uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens.WETH, accountToSaveBalances) - 1;
//         vm.prank(USER);
//         lido.submit(balanceToSwap, DUMB_ADDRESS);
//         comparator.takeSnapshot("after_submitAll", accountToSaveBalances);
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

// /// @dev [L-LDOET-1]: Lido adapter and normal account works identically
// function test_live_LDOET_01_Lido_adapter_and_normal_account_works_identically() public liveTest {
//     ICreditFacadeV3 creditFacade = lts.creditFacades(Tokens.WETH);

//     (uint256 minAmount,) = creditFacade.limits();

//     address creditAccount = openCreditAccountWithEqualAmount(minAmount);

//     uint256 snapshot = vm.snapshot();

//     compareBehavior(supportedContracts.addressOf(Contracts.LIDO_STETH_GATEWAY), USER, false);

//     /// Stores save balances in memory, because all state data would be reverted afer snapshot
//     BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(USER);

//     vm.revertTo(snapshot);

//     compareBehavior(getAdapter(Tokens.WETH, Contracts.LIDO_STETH_GATEWAY), creditAccount, true);

//     comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
// }
}
