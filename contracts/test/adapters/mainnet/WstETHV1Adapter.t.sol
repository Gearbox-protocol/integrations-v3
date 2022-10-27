// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { PoolService } from "@gearbox-protocol/core-v2/contracts/pool/PoolService.sol";
import { CreditFacade } from "@gearbox-protocol/core-v2/contracts/credit/CreditFacade.sol";

import { CreditManager } from "@gearbox-protocol/core-v2/contracts/credit/CreditManager.sol";

// TEST
import "../../lib/constants.sol";
import { Tokens } from "../../config/Tokens.sol";

// SUITES

import { LiveEnvHelper } from "../../suites/LiveEnvHelper.sol";
import { IwstETH } from "../../../integrations/lido/IwstETH.sol";

contract LiveWstETHV1AdapterTest is DSTest, LiveEnvHelper {
    function setUp() public liveOnly {
        _setUp();
    }

    /// @dev [WSTETHA-1]: Credit account for wsteth CM can be opened
    function test_live_WSTETHA_01_credit_account_can_be_opened()
        public
        liveOnly
    {
        CreditFacade cf = lts.creditFacades(Tokens.wstETH);
        CreditManager cm = lts.creditManagers(Tokens.wstETH);

        tokenTestSuite.mint(Tokens.STETH, USER, wstETH_ACCOUNT_AMOUNT);

        tokenTestSuite.approve(
            Tokens.STETH,
            USER,
            tokenTestSuite.addressOf(Tokens.wstETH)
        );

        IwstETH wstETH = IwstETH(tokenTestSuite.addressOf(Tokens.wstETH));

        evm.startPrank(USER);

        uint256 amount = wstETH.wrap(wstETH_ACCOUNT_AMOUNT);
        wstETH.approve(address(cm), type(uint256).max);

        cf.openCreditAccount(amount, USER, 300, 0);
        evm.stopPrank();
    }
}
