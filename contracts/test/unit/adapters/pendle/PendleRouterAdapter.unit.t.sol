// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.17;

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

    function setUp() public {
        _setUp();

        pendleRouter = makeAddr("PENDLE_ROUTER");
        market = makeAddr("PENDLE_MARKET");
        pt = tokens[1];

        adapter = new PendleRouterAdapter(address(creditManager), pendleRouter);

        vm.mockCall(market, abi.encodeCall(IPendleMarket.readTokens, ()), abi.encode(address(0), pt, address(0)));

        _setPairStatus(market, tokens[0], pt, PendleStatus.ALLOWED);
    }

    /// @notice U:[PEND-1]: Constructor works as expected
    function test_U_PEND_01_constructor_works_as_expected() public {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
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
            tokenOut: pt,
            callData: abi.encodeCall(
                IPendleRouter.swapExactTokenForPt, (creditAccount, market, 0, approxParams, input, limitOrderData)
            ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.swapExactTokenForPt(address(0), market, 0, approxParams, input, limitOrderData);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
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
            tokenOut: pt,
            callData: abi.encodeCall(
                IPendleRouter.swapExactTokenForPt,
                (creditAccount, market, diffInputAmount / 2, approxParams, input, limitOrderData)
            ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.swapDiffTokenForPt(market, 0.5e27, approxParams, TokenDiffInput(tokens[0], diffLeftoverAmount));

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 1 : 0, "Incorrect tokensToDisable");
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
            tokenOut: tokens[0],
            callData: abi.encodeCall(
                IPendleRouter.swapExactPtForToken, (creditAccount, market, 100, output, limitOrderData)
            ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.swapExactPtForToken(address(0), market, 100, output, limitOrderData);

        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
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
            tokenOut: tokens[0],
            callData: abi.encodeCall(
                IPendleRouter.swapExactPtForToken, (creditAccount, market, diffInputAmount, output, limitOrderData)
            ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.swapDiffPtForToken(market, diffLeftoverAmount, TokenDiffOutput(tokens[0], 0.5e27));

        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 2 : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[PEND-7]: `setPairStatusBatch` works as expected
    function test_U_PEND_07_setPairStatusBatch_works_as_expected() public {
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
