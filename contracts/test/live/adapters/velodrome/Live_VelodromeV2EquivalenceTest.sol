// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IVelodromeV2Router, Route} from "../../../../integrations/velodrome/IVelodromeV2Router.sol";
import {IVelodromeV2RouterAdapter} from "../../../../interfaces/velodrome/IVelodromeV2RouterAdapter.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";

import {
    VelodromeV2Router_Calls,
    VelodromeV2Router_Multicaller
} from "../../../multicall/velodrome/VelodromeV2Router_Calls.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_VelodromeV2EquivalenceTest is LiveTestHelper {
    using VelodromeV2Router_Calls for VelodromeV2Router_Multicaller;

    address constant DEFAULT_VELODROME_V2_FACTORY = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;

    BalanceComparator comparator;

    /// HELPER

    function prepareComparator() internal {
        Tokens[2] memory tokensToTrack = [Tokens.OP, Tokens.USDC];

        // STAGES
        string[2] memory stages = ["after_swapExactTokensForTokens", "after_swapDiffTokensForTokens"];

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

    function compareBehavior(address creditAccount, address velodromeRouterAddr, bool isAdapter) internal {
        if (isAdapter) {
            VelodromeV2Router_Multicaller router = VelodromeV2Router_Multicaller(velodromeRouterAddr);

            vm.startPrank(USER);

            Route[] memory routes = new Route[](1);

            routes[0] = Route({
                from: tokenTestSuite.addressOf(Tokens.OP),
                to: tokenTestSuite.addressOf(Tokens.USDC),
                stable: false,
                factory: DEFAULT_VELODROME_V2_FACTORY
            });

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(
                    router.swapExactTokensForTokens(WAD, 0, routes, creditAccount, block.timestamp + 3600)
                )
            );
            comparator.takeSnapshot("after_swapExactTokensForTokens", creditAccount);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(router.swapDiffTokensForTokens(WAD, 0, routes, block.timestamp + 3600))
            );
            comparator.takeSnapshot("after_swapDiffTokensForTokens", creditAccount);

            vm.stopPrank();
        } else {
            IVelodromeV2Router router = IVelodromeV2Router(velodromeRouterAddr);

            vm.startPrank(creditAccount);

            Route[] memory routes = new Route[](1);

            routes[0] = Route({
                from: tokenTestSuite.addressOf(Tokens.OP),
                to: tokenTestSuite.addressOf(Tokens.USDC),
                stable: false,
                factory: DEFAULT_VELODROME_V2_FACTORY
            });

            router.swapExactTokensForTokens(WAD, 0, routes, creditAccount, block.timestamp + 3600);
            comparator.takeSnapshot("after_swapExactTokensForTokens", creditAccount);

            uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens.OP, creditAccount) - WAD;
            router.swapExactTokensForTokens(balanceToSwap, 0, routes, creditAccount, block.timestamp + 3600);
            comparator.takeSnapshot("after_swapDiffTokensForTokens", creditAccount);

            vm.stopPrank();
        }
    }

    /// @dev Opens credit account for USER and make amount of desired token equal
    /// amounts for USER and CA to be able to launch test for both
    function openCreditAccountWithOP(uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);
        tokenTestSuite.mint(Tokens.OP, creditAccount, amount);
    }

    /// @dev [L-VELO2ET-1]: VelodromeV2 adapter and normal account works identically
    function test_live_VELO2ET_01_VelodromeV2_adapter_and_normal_account_works_identically() public attachOrLiveTest {
        prepareComparator();

        address routerAdapter = getAdapter(address(creditManager), Contracts.VELODROME_V2_ROUTER);

        if (
            routerAdapter == address(0)
                || !IVelodromeV2RouterAdapter(routerAdapter).isPoolAllowed(
                    tokenTestSuite.addressOf(Tokens.OP),
                    tokenTestSuite.addressOf(Tokens.USDC),
                    false,
                    DEFAULT_VELODROME_V2_FACTORY
                )
        ) {
            return;
        }

        address creditAccount = openCreditAccountWithOP(100 * WAD);

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.OP),
            creditAccount,
            supportedContracts.addressOf(Contracts.VELODROME_V2_ROUTER)
        );

        uint256 snapshot = vm.snapshot();

        compareBehavior(creditAccount, supportedContracts.addressOf(Contracts.VELODROME_V2_ROUTER), false);

        /// Stores save balances in memory, because all state data would be reverted afer snapshot
        BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

        vm.revertTo(snapshot);

        compareBehavior(creditAccount, getAdapter(address(creditManager), Contracts.VELODROME_V2_ROUTER), true);

        comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
    }
}
