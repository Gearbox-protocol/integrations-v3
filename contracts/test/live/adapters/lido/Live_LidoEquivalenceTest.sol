// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";

import {ILidoV1Adapter} from "../../../../interfaces/lido/ILidoV1Adapter.sol";
import {LidoV1Gateway} from "../../../../helpers/lido/LidoV1_WETHGateway.sol";
import {LidoV1_Calls, LidoV1_Multicaller} from "../../../multicall/lido/LidoV1_Calls.sol";

import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_LidoEquivalenceTest is LiveTestHelper {
    using LidoV1_Calls for LidoV1_Multicaller;

    BalanceComparator comparator;

    /// HELPER

    function prepareComparator() internal {
        uint256[2] memory tokensToTrack = [TOKEN_WETH, TOKEN_STETH];

        // STAGES
        string[2] memory stages = ["after_submit", "after_submitDiff"];

        /// @notice Sets comparator for this equivalence test

        uint256 len = stages.length;
        string[] memory _stages = new string[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _stages[i] = stages[i];
            }
        }

        len = tokensToTrack.length;
        uint256[] memory _tokensToTrack = new uint256[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _tokensToTrack[i] = tokensToTrack[i];
            }
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    function compareBehavior(address creditAccount, address lidoAddr, bool isAdapter) internal {
        if (isAdapter) {
            LidoV1_Multicaller lido = LidoV1_Multicaller(lidoAddr);

            vm.startPrank(USER);
            creditFacade.multicall(creditAccount, MultiCallBuilder.build(lido.submit(WAD)));
            comparator.takeSnapshot("after_submit", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(lido.submitDiff(WAD)));
            comparator.takeSnapshot("after_submitDiff", creditAccount);

            vm.stopPrank();
        } else {
            LidoV1Gateway lido = LidoV1Gateway(payable(lidoAddr));

            vm.startPrank(creditAccount);
            lido.submit(WAD, DUMB_ADDRESS);
            comparator.takeSnapshot("after_submit", creditAccount);

            uint256 remainingBalance = tokenTestSuite.balanceOf(TOKEN_WETH, creditAccount);
            lido.submit(remainingBalance - WAD, DUMB_ADDRESS);
            comparator.takeSnapshot("after_submitDiff", creditAccount);

            vm.stopPrank();
        }
    }

    /// @dev Opens credit account for USER and make amount of desired token equal
    /// amounts for USER and CA to be able to launch test for both
    function openCreditAccountWithWeth(uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        tokenTestSuite.mint(TOKEN_WETH, creditAccount, amount);
    }

    /// @dev [L-LDOET-1]: Lido adapter and normal account works identically
    function test_live_LDOET_01_Lido_adapter_and_normal_account_works_identically() public attachOrLiveTest {
        prepareComparator();

        address creditAccount = openCreditAccountWithWeth(10 * 10 ** 18);

        address lidoGateway = supportedContracts.addressOf(Contracts.LIDO_STETH_GATEWAY);
        address lidoAdapter = getAdapter(address(creditManager), Contracts.LIDO_STETH_GATEWAY);

        if (lidoAdapter == address(0)) return;

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(TOKEN_WETH),
            creditAccount,
            supportedContracts.addressOf(Contracts.LIDO_STETH_GATEWAY)
        );
        tokenTestSuite.approve(
            tokenTestSuite.addressOf(TOKEN_STETH),
            creditAccount,
            supportedContracts.addressOf(Contracts.LIDO_STETH_GATEWAY)
        );

        uint256 snapshot = vm.snapshot();

        compareBehavior(creditAccount, lidoGateway, false);

        BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

        vm.revertTo(snapshot);

        compareBehavior(creditAccount, lidoAdapter, true);

        comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
    }
}
