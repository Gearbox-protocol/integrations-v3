// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

// import {PoolService} from "@gearbox-protocol/core-v2/contracts/pool/PoolService.sol";
// import {CreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/credit/CreditFacadeV3.sol";

// import {CreditManagerV3} from "@gearbox-protocol/core-v3/contracts/credit/CreditManagerV3.sol";

// // TEST
// import "../../../lib/constants.sol";
// import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";

// // SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
// import {IwstETH} from "../../../../integrations/lido/IwstETH.sol";

contract LiveWstETHV1AdapterTest is LiveTestHelper {
// function setUp() public liveTest {
//     _setUp();
// }

// /// @dev [WSTETHA-1]: Credit account for wsteth CM can be opened
// function test_live_WSTETHA_01_credit_account_can_be_opened() public liveTest {
//     CreditFacadeV3 cf = lts.creditFacades(Tokens.wstETH);
//     CreditManagerV3 cm = lts.CreditManagerV3s(Tokens.wstETH);

//     tokenTestSuite.mint(Tokens.STETH, USER, wstETH_ACCOUNT_AMOUNT);

//     tokenTestSuite.approve(Tokens.STETH, USER, tokenTestSuite.addressOf(Tokens.wstETH));

//     IwstETH wstETH = IwstETH(tokenTestSuite.addressOf(Tokens.wstETH));

//     vm.startPrank(USER);

//     uint256 amount = wstETH.wrap(wstETH_ACCOUNT_AMOUNT);
//     wstETH.approve(address(cm), type(uint256).max);

//     cf.openCreditAccount(amount, USER, 300, 0);
//     vm.stopPrank();
// }
}
