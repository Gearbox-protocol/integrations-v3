// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";

import {IwstETHV1Adapter} from "../../../../interfaces/lido/IwstETHV1Adapter.sol";
import {IwstETH} from "../../../../integrations/lido/IwstETH.sol";
import {WstETHV1_Calls, WstETHV1_Multicaller} from "../../../multicall/lido/WstETHV1_Calls.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract LiveWstETHV1AdapterTest is LiveTestHelper {
    using WstETHV1_Calls for WstETHV1_Multicaller;

    BalanceComparator comparator;

    function prepareComparator() internal {
        Tokens[2] memory tokensToTrack = [Tokens.wstETH, Tokens.STETH];

        // STAGES
        string[4] memory stages = ["after_wrap", "after_wrapDiff", "after_unwrap", "after_unwrapDiff"];

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

    function compareBehavior(address creditAccount, address wstethAddr, bool isAdapter) internal {
        if (isAdapter) {
            WstETHV1_Multicaller wsteth = WstETHV1_Multicaller(wstethAddr);

            vm.startPrank(USER);
            creditFacade.multicall(creditAccount, MultiCallBuilder.build(wsteth.unwrap(WAD)));
            comparator.takeSnapshot("after_unwrap", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(wsteth.unwrapDiff(WAD)));
            comparator.takeSnapshot("after_unwrapDiff", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(wsteth.wrap(WAD)));
            comparator.takeSnapshot("after_wrap", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(wsteth.wrapDiff(WAD)));
            comparator.takeSnapshot("after_wrapDiff", creditAccount);

            vm.stopPrank();
        } else {
            IwstETH wsteth = IwstETH(wstethAddr);

            vm.startPrank(creditAccount);
            wsteth.unwrap(WAD);
            comparator.takeSnapshot("after_unwrap", creditAccount);

            uint256 remainingBalance = tokenTestSuite.balanceOf(Tokens.wstETH, creditAccount);
            wsteth.unwrap(remainingBalance - WAD);
            comparator.takeSnapshot("after_unwrapDiff", creditAccount);

            wsteth.wrap(WAD);
            comparator.takeSnapshot("after_wrap", creditAccount);

            remainingBalance = tokenTestSuite.balanceOf(Tokens.STETH, creditAccount);
            wsteth.wrap(remainingBalance - WAD);
            comparator.takeSnapshot("after_wrapDiff", creditAccount);

            vm.stopPrank();
        }
    }

    /// @dev Opens credit account for USER and make amount of desired token equal
    /// amounts for USER and CA to be able to launch test for both
    function openCreditAccountWithWstETH(uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        tokenTestSuite.mint(Tokens.wstETH, creditAccount, amount);
    }

    /// @dev [L-WSEET-1]: wstETH adapter and normal account works identically
    function test_live_WSEET_01_wstETH_adapter_and_normal_account_works_identically() public attachOrLiveTest {
        prepareComparator();

        address creditAccount = openCreditAccountWithWstETH(10 * 10 ** 18);

        address wsteth = supportedContracts.addressOf(Contracts.LIDO_WSTETH);
        address wstethAdapter = getAdapter(address(creditManager), Contracts.LIDO_WSTETH);

        if (wstethAdapter == address(0)) return;

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.wstETH), creditAccount, supportedContracts.addressOf(Contracts.LIDO_WSTETH)
        );
        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.STETH), creditAccount, supportedContracts.addressOf(Contracts.LIDO_WSTETH)
        );

        uint256 snapshot = vm.snapshot();

        compareBehavior(creditAccount, wsteth, false);

        BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

        vm.revertTo(snapshot);

        compareBehavior(creditAccount, wstethAdapter, true);

        comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
    }
}
