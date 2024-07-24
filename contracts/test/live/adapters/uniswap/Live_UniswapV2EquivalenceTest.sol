// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IUniswapV2Router02} from "../../../../integrations/uniswap/IUniswapV2Router02.sol";
import {IUniswapV2Adapter} from "../../../../interfaces/uniswap/IUniswapV2Adapter.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";

import {UniswapV2_Calls, UniswapV2_Multicaller} from "../../../multicall/uniswap/UniswapV2_Calls.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_UniswapV2EquivalenceTest is LiveTestHelper {
    using UniswapV2_Calls for UniswapV2_Multicaller;

    BalanceComparator comparator;

    /// HELPER

    function prepareComparator() internal {
        Tokens[2] memory tokensToTrack = [Tokens.WETH, Tokens.USDC];

        // STAGES
        string[3] memory stages =
            ["after_swapTokensForExactTokens", "after_swapExactTokensForTokens", "after_swapDiffTokensForTokens"];

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

    function compareBehavior(address creditAccount, address uniswapRouterAddr, bool isAdapter) internal {
        if (isAdapter) {
            UniswapV2_Multicaller router = UniswapV2_Multicaller(uniswapRouterAddr);

            vm.startPrank(USER);

            address[] memory path = new address[](2);
            path[0] = tokenTestSuite.addressOf(Tokens.WETH);
            path[1] = tokenTestSuite.addressOf(Tokens.USDC);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(
                    router.swapTokensForExactTokens(
                        100 * 10 ** 6, type(uint256).max, path, creditAccount, block.timestamp + 3600
                    )
                )
            );
            comparator.takeSnapshot("after_swapTokensForExactTokens", creditAccount);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(
                    router.swapExactTokensForTokens(WAD, 0, path, creditAccount, block.timestamp + 3600)
                )
            );
            comparator.takeSnapshot("after_swapExactTokensForTokens", creditAccount);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(router.swapDiffTokensForTokens(WAD, 0, path, block.timestamp + 3600))
            );
            comparator.takeSnapshot("after_swapDiffTokensForTokens", creditAccount);

            vm.stopPrank();
        } else {
            IUniswapV2Router02 router = IUniswapV2Router02(uniswapRouterAddr);

            vm.startPrank(creditAccount);

            address[] memory path = new address[](2);
            path[0] = tokenTestSuite.addressOf(Tokens.WETH);
            path[1] = tokenTestSuite.addressOf(Tokens.USDC);

            router.swapTokensForExactTokens(
                100 * 10 ** 6, type(uint256).max, path, creditAccount, block.timestamp + 3600
            );
            comparator.takeSnapshot("after_swapTokensForExactTokens", creditAccount);

            router.swapExactTokensForTokens(WAD, 0, path, creditAccount, block.timestamp + 3600);
            comparator.takeSnapshot("after_swapExactTokensForTokens", creditAccount);

            uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens.WETH, creditAccount) - WAD;
            router.swapExactTokensForTokens(balanceToSwap, 0, path, creditAccount, block.timestamp + 3600);
            comparator.takeSnapshot("after_swapDiffTokensForTokens", creditAccount);

            vm.stopPrank();
        }
    }

    /// @dev Opens credit account for USER and make amount of desired token equal
    /// amounts for USER and CA to be able to launch test for both
    function openCreditAccountWithWeth(uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);
        tokenTestSuite.mint(Tokens.WETH, creditAccount, amount);
    }

    /// @dev [L-UV2ET-1]: UniswapV2 adapter and normal account works identically
    function test_live_UV2ET_01_UniswapV2_adapter_and_normal_account_works_identically() public attachOrLiveTest {
        prepareComparator();

        address creditAccount = openCreditAccountWithWeth(100 * WAD);

        address routerAdapter = getAdapter(address(creditManager), Contracts.UNISWAP_V2_ROUTER);

        if (
            routerAdapter == address(0)
                || !IUniswapV2Adapter(routerAdapter).isPairAllowed(
                    tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.USDC)
                )
        ) {
            return;
        }

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.WETH),
            creditAccount,
            supportedContracts.addressOf(Contracts.UNISWAP_V2_ROUTER)
        );

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.USDC),
            creditAccount,
            supportedContracts.addressOf(Contracts.UNISWAP_V2_ROUTER)
        );

        uint256 snapshot = vm.snapshot();

        compareBehavior(creditAccount, supportedContracts.addressOf(Contracts.UNISWAP_V2_ROUTER), false);

        /// Stores save balances in memory, because all state data would be reverted afer snapshot
        BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

        vm.revertTo(snapshot);

        compareBehavior(creditAccount, getAdapter(address(creditManager), Contracts.UNISWAP_V2_ROUTER), true);

        comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
    }
}
