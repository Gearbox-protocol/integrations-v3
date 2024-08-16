// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {
    IPendleRouter,
    IPendleMarket,
    SwapData,
    SwapType,
    TokenInput,
    TokenOutput,
    ApproxParams,
    LimitOrderData
} from "../../../../integrations/pendle/IPendleRouter.sol";
import {
    IPendleRouterAdapter,
    PendleStatus,
    TokenDiffInput,
    TokenDiffOutput,
    PendlePairStatus
} from "../../../../interfaces/pendle/IPendleRouterAdapter.sol";
import {PendleRouter_Calls, PendleRouter_Multicaller} from "../../../multicall/pendle/PendleRouter_Calls.sol";

import {Tokens, TokenType} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
import {AddressList} from "@gearbox-protocol/core-v3/contracts/test/lib/AddressList.sol";

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

contract Live_PendleRouterAdapterTest is LiveTestHelper {
    using PendleRouter_Calls for PendleRouter_Multicaller;
    using AddressList for address[];

    BalanceComparator comparator;

    string[4] stages = [
        "after_swapExactTokenForPt",
        "after_swapDiffTokenForPt",
        "after_swapExactPtForToken",
        "after_swapDiffPtForToken"
    ];

    string[] _stages;

    function setUp() public {
        uint256 len = stages.length;
        _stages = new string[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _stages[i] = stages[i];
            }
        }
    }

    function compareBehavior(address creditAccount, address routerAddress, PendlePairStatus memory pair, bool isAdapter)
        internal
    {
        if (isAdapter) {
            vm.startPrank(USER);
        } else {
            vm.startPrank(creditAccount);
        }

        uint256 baseUnit = 10 ** IERC20Metadata(pair.inputToken).decimals();

        LimitOrderData memory lod;

        if (isAdapter) {
            PendleRouter_Multicaller router = PendleRouter_Multicaller(routerAddress);

            if (pair.status == PendleStatus.ALLOWED) {
                TokenInput memory input = TokenInput({
                    tokenIn: pair.inputToken,
                    netTokenIn: 10 * baseUnit,
                    tokenMintSy: pair.inputToken,
                    pendleSwap: address(0),
                    swapData: SwapData({swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false})
                });
                creditFacade.multicall(
                    creditAccount,
                    MultiCallBuilder.build(
                        router.swapExactTokenForPt(
                            creditAccount,
                            pair.market,
                            0,
                            ApproxParams({
                                guessMin: 0,
                                guessMax: type(uint256).max,
                                guessOffchain: 0,
                                maxIteration: 256,
                                eps: 1e14
                            }),
                            input,
                            lod
                        )
                    )
                );
                comparator.takeSnapshot("after_swapExactTokenForPt", creditAccount);

                TokenDiffInput memory diffInput =
                    TokenDiffInput({tokenIn: pair.inputToken, leftoverTokenIn: 50 * baseUnit});
                creditFacade.multicall(
                    creditAccount,
                    MultiCallBuilder.build(
                        router.swapDiffTokenForPt(
                            pair.market,
                            0,
                            ApproxParams({
                                guessMin: 0,
                                guessMax: type(uint256).max,
                                guessOffchain: 0,
                                maxIteration: 256,
                                eps: 1e14
                            }),
                            diffInput
                        )
                    )
                );
                comparator.takeSnapshot("after_swapDiffTokenForPt", creditAccount);
            }

            TokenOutput memory output = TokenOutput({
                tokenOut: pair.inputToken,
                minTokenOut: 0,
                tokenRedeemSy: pair.inputToken,
                pendleSwap: address(0),
                swapData: SwapData({swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false})
            });
            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(
                    router.swapExactPtForToken(creditAccount, pair.market, 10 * baseUnit, output, lod)
                )
            );
            comparator.takeSnapshot("after_swapExactPtForToken", creditAccount);

            TokenDiffOutput memory diffOutput = TokenDiffOutput({tokenOut: pair.inputToken, minRateRAY: 0});
            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(router.swapDiffPtForToken(pair.market, 10 * baseUnit, diffOutput))
            );
            comparator.takeSnapshot("after_swapDiffPtForToken", creditAccount);
        } else {
            IPendleRouter router = IPendleRouter(routerAddress);

            if (pair.status == PendleStatus.ALLOWED) {
                TokenInput memory input = TokenInput({
                    tokenIn: pair.inputToken,
                    netTokenIn: 10 * baseUnit,
                    tokenMintSy: pair.inputToken,
                    pendleSwap: address(0),
                    swapData: SwapData({swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false})
                });
                router.swapExactTokenForPt(
                    creditAccount,
                    pair.market,
                    0,
                    ApproxParams({
                        guessMin: 0,
                        guessMax: type(uint256).max,
                        guessOffchain: 0,
                        maxIteration: 256,
                        eps: 1e14
                    }),
                    input,
                    lod
                );
                comparator.takeSnapshot("after_swapExactTokenForPt", creditAccount);

                uint256 inputBalance = IERC20(pair.inputToken).balanceOf(creditAccount);
                uint256 leftoverTokenIn = 50 * baseUnit;
                input.netTokenIn = inputBalance - leftoverTokenIn;
                router.swapExactTokenForPt(
                    creditAccount,
                    pair.market,
                    0,
                    ApproxParams({
                        guessMin: 0,
                        guessMax: type(uint256).max,
                        guessOffchain: 0,
                        maxIteration: 256,
                        eps: 1e14
                    }),
                    input,
                    lod
                );
                comparator.takeSnapshot("after_swapDiffTokenForPt", creditAccount);
            }

            TokenOutput memory output = TokenOutput({
                tokenOut: pair.inputToken,
                minTokenOut: 0,
                tokenRedeemSy: pair.inputToken,
                pendleSwap: address(0),
                swapData: SwapData({swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false})
            });
            router.swapExactPtForToken(creditAccount, pair.market, 10 * baseUnit, output, lod);
            comparator.takeSnapshot("after_swapExactPtForToken", creditAccount);

            uint256 ptBalance = IERC20(pair.pendleToken).balanceOf(creditAccount);
            uint256 leftoverPt = 10 * baseUnit;
            router.swapExactPtForToken(creditAccount, pair.market, ptBalance - leftoverPt, output, lod);
            comparator.takeSnapshot("after_swapDiffPtForToken", creditAccount);
        }

        vm.stopPrank();
    }

    function openCreditAccountWithTokens(address inputToken, address pendleToken)
        internal
        returns (address creditAccount)
    {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        uint256 inputAmount = 100 * 10 ** IERC20Metadata(inputToken).decimals();
        uint256 pendleTokenAmount = 100 * 10 ** IERC20Metadata(pendleToken).decimals();

        tokenTestSuite.mint(inputToken, creditAccount, inputAmount);
        tokenTestSuite.mint(pendleToken, creditAccount, pendleTokenAmount);
    }

    function prepareComparator(address inputToken, address pendleToken) internal {
        address[] memory tokensToTrack = new address[](2);
        tokensToTrack[0] = inputToken;
        tokensToTrack[1] = pendleToken;

        Tokens[] memory _tokensToTrack = new Tokens[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; j++) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    /// @dev [L-PEND-1]: Pendle Router adapter and original contract work identically
    function test_live_PEND_01_PendleRouter_adapter_and_original_contract_are_equivalent() public attachOrLiveTest {
        address pendleRouterAdapter = getAdapter(address(creditManager), Contracts.PENDLE_ROUTER);

        if (pendleRouterAdapter == address(0)) return;

        address pendleRouter = IAdapter(pendleRouterAdapter).targetContract();
        PendlePairStatus[] memory allowedPairs = IPendleRouterAdapter(pendleRouterAdapter).getAllowedPairs();

        for (uint256 i = 0; i < allowedPairs.length; ++i) {
            PendlePairStatus memory pair = allowedPairs[i];

            address creditAccount = openCreditAccountWithTokens(pair.inputToken, pair.pendleToken);

            tokenTestSuite.approve(pair.inputToken, creditAccount, pendleRouter);
            tokenTestSuite.approve(pair.pendleToken, creditAccount, pendleRouter);

            uint256 snapshot = vm.snapshot();

            prepareComparator(pair.inputToken, pair.pendleToken);

            compareBehavior(creditAccount, pendleRouter, pair, false);

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot);

            prepareComparator(pair.inputToken, pair.pendleToken);

            compareBehavior(creditAccount, pendleRouterAdapter, pair, true);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots, 0);
        }
    }
}
