// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICamelotV3Router} from "../../../../integrations/camelot/ICamelotV3Router.sol";
import {ICamelotV3Adapter, ICamelotV3AdapterTypes} from "../../../../interfaces/camelot/ICamelotV3Adapter.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";

import {CamelotV3_Calls, CamelotV3_Multicaller} from "../../../multicall/Camelot/CamelotV3_Calls.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_CamelotV3EquivalenceTest is LiveTestHelper {
    using CamelotV3_Calls for CamelotV3_Multicaller;

    BalanceComparator comparator;

    /// HELPER

    function prepareComparator() internal {
        Tokens[2] memory tokensToTrack = [Tokens.WETH, Tokens.USDC];

        // STAGES
        string[8] memory stages = [
            "after_exactInputSingle",
            "after_exactDiffInputSingle",
            "after_exactInputSingleSupportingFeeOnTransferTokens",
            "after_exactDiffInputSingleSupportingFeeOnTransferTokens",
            "after_exactInput",
            "after_exactDiffInput",
            "after_exactOutputSingle",
            "after_exactOutput"
        ];

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

    function compareBehavior(address creditAccount, address camelotRouterAddr, bool isAdapter) internal {
        if (isAdapter) {
            CamelotV3_Multicaller router = CamelotV3_Multicaller(camelotRouterAddr);

            vm.startPrank(USER);

            ICamelotV3Router.ExactInputSingleParams memory exactInputSingleParams = ICamelotV3Router
                .ExactInputSingleParams({
                tokenIn: tokenTestSuite.addressOf(Tokens.WETH),
                tokenOut: tokenTestSuite.addressOf(Tokens.USDC),
                recipient: creditAccount,
                deadline: block.timestamp + 3600,
                amountIn: WAD,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            });

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(router.exactInputSingle(exactInputSingleParams))
            );
            comparator.takeSnapshot("after_exactInputSingle", creditAccount);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(router.exactInputSingleSupportingFeeOnTransferTokens(exactInputSingleParams))
            );
            comparator.takeSnapshot("after_exactInputSingleSupportingFeeOnTransferTokens", creditAccount);

            ICamelotV3AdapterTypes.ExactDiffInputSingleParams memory exactDiffInputSingleParams = ICamelotV3AdapterTypes
                .ExactDiffInputSingleParams({
                tokenIn: tokenTestSuite.addressOf(Tokens.WETH),
                tokenOut: tokenTestSuite.addressOf(Tokens.USDC),
                deadline: block.timestamp + 3600,
                leftoverAmount: 20 * WAD,
                rateMinRAY: 0,
                limitSqrtPrice: 0
            });

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(router.exactDiffInputSingle(exactDiffInputSingleParams))
            );
            comparator.takeSnapshot("after_exactDiffInputSingle", creditAccount);

            exactDiffInputSingleParams.leftoverAmount = 19 * WAD;

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(
                    router.exactDiffInputSingleSupportingFeeOnTransferTokens(exactDiffInputSingleParams)
                )
            );
            comparator.takeSnapshot("after_exactDiffInputSingleSupportingFeeOnTransferTokens", creditAccount);

            ICamelotV3Router.ExactInputParams memory exactInputParams = ICamelotV3Router.ExactInputParams({
                path: abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.USDC)),
                recipient: creditAccount,
                deadline: block.timestamp + 3600,
                amountIn: WAD,
                amountOutMinimum: 0
            });
            creditFacade.multicall(creditAccount, MultiCallBuilder.build(router.exactInput(exactInputParams)));
            comparator.takeSnapshot("after_exactInput", creditAccount);

            ICamelotV3AdapterTypes.ExactDiffInputParams memory exactDiffInputParams = ICamelotV3AdapterTypes
                .ExactDiffInputParams({
                path: abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.USDC)),
                deadline: block.timestamp + 3600,
                leftoverAmount: 10 * WAD,
                rateMinRAY: 0
            });
            creditFacade.multicall(creditAccount, MultiCallBuilder.build(router.exactDiffInput(exactDiffInputParams)));
            comparator.takeSnapshot("after_exactDiffInput", creditAccount);

            ICamelotV3Router.ExactOutputSingleParams memory exactOutputSingleParams = ICamelotV3Router
                .ExactOutputSingleParams({
                tokenIn: tokenTestSuite.addressOf(Tokens.WETH),
                tokenOut: tokenTestSuite.addressOf(Tokens.USDC),
                fee: 0,
                recipient: creditAccount,
                deadline: block.timestamp + 3600,
                amountOut: 100 * 10 ** 6,
                amountInMaximum: type(uint256).max,
                limitSqrtPrice: 0
            });
            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(router.exactOutputSingle(exactOutputSingleParams))
            );
            comparator.takeSnapshot("after_exactOutputSingle", creditAccount);

            ICamelotV3Router.ExactOutputParams memory exactOutputParams = ICamelotV3Router.ExactOutputParams({
                path: abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.USDC)),
                recipient: creditAccount,
                deadline: block.timestamp + 3600,
                amountOut: 100 * 10 ** 6,
                amountInMaximum: type(uint256).max
            });
            creditFacade.multicall(creditAccount, MultiCallBuilder.build(router.exactOutput(exactOutputParams)));
            comparator.takeSnapshot("after_exactOutput", creditAccount);

            vm.stopPrank();
        } else {
            ICamelotV3Router router = ICamelotV3Router(camelotRouterAddr);

            vm.startPrank(creditAccount);

            router.exactInputSingle(
                ICamelotV3Router.ExactInputSingleParams({
                    tokenIn: tokenTestSuite.addressOf(Tokens.WETH),
                    tokenOut: tokenTestSuite.addressOf(Tokens.USDC),
                    recipient: creditAccount,
                    deadline: block.timestamp + 3600,
                    amountIn: WAD,
                    amountOutMinimum: 0,
                    limitSqrtPrice: 0
                })
            );

            comparator.takeSnapshot("after_exactInputSingle", creditAccount);

            router.exactInputSingleSupportingFeeOnTransferTokens(
                ICamelotV3Router.ExactInputSingleParams({
                    tokenIn: tokenTestSuite.addressOf(Tokens.WETH),
                    tokenOut: tokenTestSuite.addressOf(Tokens.USDC),
                    recipient: creditAccount,
                    deadline: block.timestamp + 3600,
                    amountIn: WAD,
                    amountOutMinimum: 0,
                    limitSqrtPrice: 0
                })
            );

            comparator.takeSnapshot("after_exactInputSingleSupportingFeeOnTransferTokens", creditAccount);

            uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens.WETH, creditAccount) - 20 * WAD;
            router.exactInputSingle(
                ICamelotV3Router.ExactInputSingleParams({
                    tokenIn: tokenTestSuite.addressOf(Tokens.WETH),
                    tokenOut: tokenTestSuite.addressOf(Tokens.USDC),
                    recipient: creditAccount,
                    deadline: block.timestamp + 3600,
                    amountIn: balanceToSwap,
                    amountOutMinimum: 0,
                    limitSqrtPrice: 0
                })
            );
            comparator.takeSnapshot("after_exactDiffInputSingle", creditAccount);

            balanceToSwap = tokenTestSuite.balanceOf(Tokens.WETH, creditAccount) - 19 * WAD;
            router.exactInputSingleSupportingFeeOnTransferTokens(
                ICamelotV3Router.ExactInputSingleParams({
                    tokenIn: tokenTestSuite.addressOf(Tokens.WETH),
                    tokenOut: tokenTestSuite.addressOf(Tokens.USDC),
                    recipient: creditAccount,
                    deadline: block.timestamp + 3600,
                    amountIn: balanceToSwap,
                    amountOutMinimum: 0,
                    limitSqrtPrice: 0
                })
            );
            comparator.takeSnapshot("after_exactDiffInputSingleSupportingFeeOnTransferTokens", creditAccount);

            router.exactInput(
                ICamelotV3Router.ExactInputParams({
                    path: abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.USDC)),
                    recipient: creditAccount,
                    deadline: block.timestamp + 3600,
                    amountIn: WAD,
                    amountOutMinimum: 0
                })
            );
            comparator.takeSnapshot("after_exactInput", creditAccount);

            balanceToSwap = tokenTestSuite.balanceOf(Tokens.WETH, creditAccount) - 10 * WAD;
            router.exactInput(
                ICamelotV3Router.ExactInputParams({
                    path: abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.USDC)),
                    recipient: creditAccount,
                    deadline: block.timestamp + 3600,
                    amountIn: balanceToSwap,
                    amountOutMinimum: 0
                })
            );
            comparator.takeSnapshot("after_exactDiffInput", creditAccount);

            router.exactOutputSingle(
                ICamelotV3Router.ExactOutputSingleParams({
                    tokenIn: tokenTestSuite.addressOf(Tokens.WETH),
                    tokenOut: tokenTestSuite.addressOf(Tokens.USDC),
                    fee: 0,
                    recipient: creditAccount,
                    deadline: block.timestamp + 3600,
                    amountOut: 100 * 10 ** 6,
                    amountInMaximum: type(uint256).max,
                    limitSqrtPrice: 0
                })
            );
            comparator.takeSnapshot("after_exactOutputSingle", creditAccount);

            router.exactOutput(
                ICamelotV3Router.ExactOutputParams({
                    path: abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.USDC)),
                    recipient: creditAccount,
                    deadline: block.timestamp + 3600,
                    amountOut: 100 * 10 ** 6,
                    amountInMaximum: type(uint256).max
                })
            );
            comparator.takeSnapshot("after_exactOutput", creditAccount);

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

    /// @dev [L-CAMV3ET-1]: CamelotV3 adapter and normal account works identically
    function test_live_CAMV3ET_01_CamelotV3_adapter_and_normal_account_works_identically() public attachOrLiveTest {
        prepareComparator();

        address creditAccount = openCreditAccountWithWeth(30 * WAD);

        address routerAdapter = getAdapter(address(creditManager), Contracts.CAMELOT_V3_ROUTER);

        if (
            routerAdapter == address(0)
                || !ICamelotV3Adapter(routerAdapter).isPoolAllowed(
                    tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.USDC)
                )
        ) {
            return;
        }

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.WETH),
            creditAccount,
            supportedContracts.addressOf(Contracts.CAMELOT_V3_ROUTER)
        );

        tokenTestSuite.approve(
            tokenTestSuite.addressOf(Tokens.USDC),
            creditAccount,
            supportedContracts.addressOf(Contracts.CAMELOT_V3_ROUTER)
        );

        uint256 snapshot = vm.snapshot();

        compareBehavior(creditAccount, supportedContracts.addressOf(Contracts.CAMELOT_V3_ROUTER), false);

        /// Stores save balances in memory, because all state data would be reverted afer snapshot
        BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

        vm.revertTo(snapshot);

        compareBehavior(creditAccount, getAdapter(address(creditManager), Contracts.CAMELOT_V3_ROUTER), true);

        comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
    }
}
