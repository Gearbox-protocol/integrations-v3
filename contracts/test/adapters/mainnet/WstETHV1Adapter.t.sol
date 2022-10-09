// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;

import { CreditFacade } from "@gearbox-protocol/core-v2/contracts/credit/CreditFacade.sol";
import { ICreditFacade } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import { ILidoV1Adapter } from "../../../interfaces/adapters/lido/ILidoV1Adapter.sol";
import { ICurveV1Adapter } from "../../../interfaces/adapters/curve/ICurveV1Adapter.sol";
import { CreditManager } from "@gearbox-protocol/core-v2/contracts/credit/CreditManager.sol";
import { Balance, BalanceOps } from "@gearbox-protocol/core-v2/contracts/libraries/Balances.sol";
import { MultiCall, MultiCallOps } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import { ConvexStakedPositionToken } from "../../../adapters/convex/ConvexV1_StakedPositionToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// TEST
import "../../lib/constants.sol";
import { Tokens } from "../../config/Tokens.sol";
import { Contracts } from "../../config/SupportedContracts.sol";

// SUITES
import { LiveEnvTestSuite } from "../../suites/LiveEnvTestSuite.sol";
import { LiveEnvHelper } from "../../suites/LiveEnvHelper.sol";
import { IwstETH } from "../../../integrations/lido/IwstETH.sol";

contract LiveWstETHV1AdapterTest is DSTest, LiveEnvHelper {
    function setUp() public liveOnly {
        _setUp();
    }

    /// @dev [WSTETHA-1]: Credit account for wsteth CM can be opened
    function test_WSTETHA_01_credit_account_can_be_opened() public liveOnly {
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
