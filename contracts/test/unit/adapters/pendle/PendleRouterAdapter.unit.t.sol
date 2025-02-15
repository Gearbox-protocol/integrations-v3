// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    IPendleRouter,
    IPendleMarket,
    IYToken,
    IPToken,
    SwapData,
    SwapType,
    TokenInput,
    TokenOutput,
    ApproxParams,
    LimitOrderData
} from "../../../../integrations/pendle/IPendleRouter.sol";
import {
    IPendleRouterAdapterEvents,
    IPendleRouterAdapterExceptions,
    PendlePairStatus,
    TokenDiffInput,
    TokenDiffOutput,
    PendleStatus
} from "../../../../interfaces/pendle/IPendleRouterAdapter.sol";
import {PendleRouterAdapter} from "../../../../adapters/pendle/PendleRouterAdapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Pendle Router adapter unit test
/// @notice U:[PEND]: Unit tests for Pendle Router adapter
contract PendleRouterAdapterUnitTest is
    AdapterUnitTestHelper,
    IPendleRouterAdapterEvents,
    IPendleRouterAdapterExceptions
{
    PendleRouterAdapter adapter;

    address pendleRouter;
    address market;
    address pt;
    address yt;

    function setUp() public {
        _setUp();

        pendleRouter = makeAddr("PENDLE_ROUTER");
        market = makeAddr("PENDLE_MARKET");
        pt = tokens[1];
        yt = makeAddr("YT_TOKEN");

        adapter = new PendleRouterAdapter(address(creditManager), pendleRouter);

        vm.mockCall(market, abi.encodeCall(IPendleMarket.readTokens, ()), abi.encode(address(0), pt, address(0)));
        vm.mockCall(yt, abi.encodeCall(IYToken.PT, ()), abi.encode(pt));

        _setPairStatus(market, tokens[0], pt, PendleStatus.ALLOWED);
    }

    /// @notice U:[PEND-1]: Constructor works as expected
    function test_U_PEND_01_constructor_works_as_expected() public view {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), pendleRouter, "Incorrect targetContract");
    }

    /// @notice U:[PEND-2]: Wrapper functions revert on wrong caller
    function test_U_PEND_02_wrapper_functions_revert_on_wrong_caller() public {
        TokenInput memory input;
        LimitOrderData memory limitOrderData;
        ApproxParams memory approxParams;

        _revertsOnNonFacadeCaller();
        adapter.swapExactTokenForPt(address(0), market, 0, approxParams, input, limitOrderData);

        _revertsOnNonFacadeCaller();
        adapter.swapDiffTokenForPt(market, 0, approxParams, TokenDiffInput(address(0), 0));

        TokenOutput memory output;

        _revertsOnNonFacadeCaller();
        adapter.swapExactPtForToken(address(0), market, 0, output, limitOrderData);

        _revertsOnNonFacadeCaller();
        adapter.swapDiffPtForToken(market, 0, TokenDiffOutput(address(0), 0));

        _revertsOnNonFacadeCaller();
        adapter.redeemPyToToken(address(0), yt, 0, output);

        _revertsOnNonFacadeCaller();
        adapter.redeemDiffPyToToken(yt, 0, TokenDiffOutput(address(0), 0));
    }

    /// @notice U:[PEND-3]: `swapExactTokenForPt` works as expected
    function test_U_PEND_03_swapExactTokenForPt_works_as_expected() public {
        TokenInput memory input;
        input.tokenIn = tokens[0];
        input.netTokenIn = 100;
        input.tokenMintSy = tokens[0];

        LimitOrderData memory limitOrderData;
        ApproxParams memory approxParams;

        address wrongMarket = makeAddr("WRONG_MARKET");

        vm.mockCall(wrongMarket, abi.encodeCall(IPendleMarket.readTokens, ()), abi.encode(address(0), pt, address(0)));

        vm.expectRevert(PairNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.swapExactTokenForPt(address(0), wrongMarket, 0, approxParams, input, limitOrderData);

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(
                IPendleRouter.swapExactTokenForPt, (creditAccount, market, 0, approxParams, input, limitOrderData)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapExactTokenForPt(address(0), market, 0, approxParams, input, limitOrderData);

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[PEND-4]: `swapDiffTokenForPt` works as expected
    function test_U_PEND_04_swapDiffTokenForPt_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        ApproxParams memory approxParams;

        address wrongMarket = makeAddr("WRONG_MARKET");

        vm.mockCall(wrongMarket, abi.encodeCall(IPendleMarket.readTokens, ()), abi.encode(address(0), pt, address(0)));

        vm.expectRevert(PairNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.swapDiffTokenForPt(wrongMarket, 0, approxParams, TokenDiffInput(tokens[0], diffLeftoverAmount));

        TokenInput memory input;
        input.tokenIn = tokens[0];
        input.netTokenIn = diffInputAmount;
        input.tokenMintSy = tokens[0];

        LimitOrderData memory limitOrderData;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            callData: abi.encodeCall(
                IPendleRouter.swapExactTokenForPt,
                (creditAccount, market, diffInputAmount / 2, approxParams, input, limitOrderData)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices =
            adapter.swapDiffTokenForPt(market, 0.5e27, approxParams, TokenDiffInput(tokens[0], diffLeftoverAmount));

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[PEND-5]: `swapExactPtForToken` works as expected
    function test_U_PEND_05_swapExactPtForToken_works_as_expected() public {
        TokenOutput memory output;
        output.tokenOut = tokens[0];
        output.minTokenOut = 90;
        output.tokenRedeemSy = tokens[0];

        LimitOrderData memory limitOrderData;

        address wrongMarket = makeAddr("WRONG_MARKET");

        vm.mockCall(wrongMarket, abi.encodeCall(IPendleMarket.readTokens, ()), abi.encode(address(0), pt, address(0)));

        vm.expectRevert(PairNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.swapExactPtForToken(address(0), wrongMarket, 100, output, limitOrderData);

        _readsActiveAccount();
        _executesSwap({
            tokenIn: pt,
            callData: abi.encodeCall(
                IPendleRouter.swapExactPtForToken, (creditAccount, market, 100, output, limitOrderData)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapExactPtForToken(address(0), market, 100, output, limitOrderData);

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[PEND-6]: `swapDiffPtForToken` works as expected
    function test_U_PEND_06_swapDiffPtForToken_works_as_expected() public diffTestCases {
        deal({token: pt, to: creditAccount, give: diffMintedAmount});

        address wrongMarket = makeAddr("WRONG_MARKET");

        vm.mockCall(wrongMarket, abi.encodeCall(IPendleMarket.readTokens, ()), abi.encode(address(0), pt, address(0)));

        vm.expectRevert(PairNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.swapDiffPtForToken(wrongMarket, diffLeftoverAmount, TokenDiffOutput(tokens[0], 0.5e27));

        TokenOutput memory output;
        output.tokenOut = tokens[0];
        output.minTokenOut = diffInputAmount / 2;
        output.tokenRedeemSy = tokens[0];

        LimitOrderData memory limitOrderData;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: pt,
            callData: abi.encodeCall(
                IPendleRouter.swapExactPtForToken, (creditAccount, market, diffInputAmount, output, limitOrderData)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.swapDiffPtForToken(market, diffLeftoverAmount, TokenDiffOutput(tokens[0], 0.5e27));

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[PEND-7]: `redeemPyToToken` works as expected
    function test_U_PEND_07_redeemPyToToken_works_as_expected() public {
        TokenOutput memory output;
        output.tokenOut = tokens[0];
        output.minTokenOut = 90;
        output.tokenRedeemSy = tokens[0];

        vm.mockCall(pt, abi.encodeCall(IPToken.YT, ()), abi.encode(yt));

        vm.mockCall(yt, abi.encodeCall(IYToken.expiry, ()), abi.encode(block.timestamp - 1));
        _setPairStatus(market, tokens[0], pt, PendleStatus.NOT_ALLOWED);

        vm.expectRevert(RedemptionNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.redeemPyToToken(address(0), yt, 100, output);

        _setPairStatus(market, tokens[0], pt, PendleStatus.ALLOWED);
        vm.mockCall(yt, abi.encodeCall(IYToken.expiry, ()), abi.encode(block.timestamp + 1));

        vm.expectRevert(RedemptionNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.redeemPyToToken(address(0), yt, 100, output);

        vm.mockCall(yt, abi.encodeCall(IYToken.expiry, ()), abi.encode(block.timestamp - 1));

        vm.mockCall(pt, abi.encodeCall(IPToken.YT, ()), abi.encode(makeAddr("WRONG_YT")));
        vm.expectRevert(RedemptionNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.redeemPyToToken(address(0), yt, 100, output);

        vm.mockCall(pt, abi.encodeCall(IPToken.YT, ()), abi.encode(yt));

        _readsActiveAccount();
        _executesSwap({
            tokenIn: pt,
            callData: abi.encodeCall(IPendleRouter.redeemPyToToken, (creditAccount, yt, 100, output)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemPyToToken(address(0), yt, 100, output);

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[PEND-8]: `redeemDiffPyToToken` works as expected
    function test_U_PEND_08_redeemDiffPyToToken_works_as_expected() public diffTestCases {
        deal({token: pt, to: creditAccount, give: diffMintedAmount});

        vm.mockCall(pt, abi.encodeCall(IPToken.YT, ()), abi.encode(yt));

        vm.mockCall(yt, abi.encodeCall(IYToken.expiry, ()), abi.encode(block.timestamp - 1));
        _setPairStatus(market, tokens[0], pt, PendleStatus.NOT_ALLOWED);

        vm.expectRevert(RedemptionNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.redeemDiffPyToToken(yt, diffLeftoverAmount, TokenDiffOutput(tokens[0], 0.5e27));

        _setPairStatus(market, tokens[0], pt, PendleStatus.ALLOWED);
        vm.mockCall(yt, abi.encodeCall(IYToken.expiry, ()), abi.encode(block.timestamp + 1));

        vm.expectRevert(RedemptionNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.redeemDiffPyToToken(yt, diffLeftoverAmount, TokenDiffOutput(tokens[0], 0.5e27));

        vm.mockCall(yt, abi.encodeCall(IYToken.expiry, ()), abi.encode(block.timestamp - 1));

        vm.mockCall(pt, abi.encodeCall(IPToken.YT, ()), abi.encode(abi.encode(makeAddr("WRONG_YT"))));
        vm.expectRevert(RedemptionNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.redeemDiffPyToToken(yt, diffLeftoverAmount, TokenDiffOutput(tokens[0], 0.5e27));

        vm.mockCall(pt, abi.encodeCall(IPToken.YT, ()), abi.encode(yt));

        TokenOutput memory output;
        output.tokenOut = tokens[0];
        output.minTokenOut = diffInputAmount / 2;
        output.tokenRedeemSy = tokens[0];

        _readsActiveAccount();
        _executesSwap({
            tokenIn: pt,
            callData: abi.encodeCall(IPendleRouter.redeemPyToToken, (creditAccount, yt, diffInputAmount, output)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemDiffPyToToken(yt, diffLeftoverAmount, TokenDiffOutput(tokens[0], 0.5e27));

        assertTrue(useSafePrices, "Should use safe prices");
    }

    /// @notice U:[PEND-9]: `setPairStatusBatch` works as expected
    function test_U_PEND_09_setPairStatusBatch_works_as_expected() public {
        PendlePairStatus[] memory pairs;

        _revertsOnNonConfiguratorCaller();
        adapter.setPairStatusBatch(pairs);

        pairs = new PendlePairStatus[](2);
        pairs[0] = PendlePairStatus(market, tokens[0], pt, PendleStatus.NOT_ALLOWED);
        pairs[1] = PendlePairStatus(market, tokens[1], pt, PendleStatus.ALLOWED);

        vm.expectEmit(true, true, true, true);
        emit SetPairStatus(market, tokens[0], pt, PendleStatus.NOT_ALLOWED);

        vm.expectEmit(true, true, true, true);
        emit SetPairStatus(market, tokens[1], pt, PendleStatus.ALLOWED);

        vm.prank(configurator);
        adapter.setPairStatusBatch(pairs);

        assertEq(
            uint256(adapter.isPairAllowed(market, tokens[0], pt)),
            uint256(PendleStatus.NOT_ALLOWED),
            "First pair status is incorrect"
        );
        assertEq(
            uint256(adapter.isPairAllowed(market, tokens[1], pt)),
            uint256(PendleStatus.ALLOWED),
            "Second pair status is incorrect"
        );
        assertEq(adapter.ptToMarket(pt), market, "Incorrect market for PT");
        assertFalse(adapter.isRedemptionAllowed(tokens[0], pt), "Incorrect redemption status for first pair");
        assertTrue(adapter.isRedemptionAllowed(tokens[1], pt), "Incorrect redemption status for second pair");

        PendlePairStatus[] memory allowedPairs = adapter.getAllowedPairs();
        assertEq(allowedPairs.length, 1, "Incorrect number of allowed pairs");
        assertEq(allowedPairs[0].market, market, "Incorrect market in allowed pairs");
        assertEq(allowedPairs[0].inputToken, tokens[1], "Incorrect input token in allowed pairs");
        assertEq(allowedPairs[0].pendleToken, pt, "Incorrect pendle token in allowed pairs");
        assertEq(uint256(allowedPairs[0].status), uint256(PendleStatus.ALLOWED), "Incorrect status in allowed pairs");
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Sets status for a Pendle pair
    function _setPairStatus(address _market, address _inputToken, address _pt, PendleStatus _status) internal {
        PendlePairStatus[] memory pairs = new PendlePairStatus[](1);
        pairs[0] = PendlePairStatus(_market, _inputToken, _pt, _status);
        vm.prank(configurator);
        adapter.setPairStatusBatch(pairs);
    }
}
