// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KelpLRTWithdrawalManagerAdapter} from "../../../../adapters/kelp/KelpLRTWithdrawalManagerAdapter.sol";
import {KelpLRTWithdrawalManagerGateway} from "../../../../helpers/kelp/KelpLRTWithdrawalManagerGateway.sol";
import {KelpLRTWithdrawalPhantomToken} from "../../../../helpers/kelp/KelpLRTWithdrawalPhantomToken.sol";
import {
    IKelpLRTWithdrawalManagerAdapter,
    TokenOutStatus
} from "../../../../interfaces/kelp/IKelpLRTWithdrawalManagerAdapter.sol";
import {IKelpLRTWithdrawalManagerGateway} from "../../../../interfaces/kelp/IKelpLRTWithdrawalManagerGateway.sol";
import {IPhantomTokenAdapter} from "../../../../interfaces/IPhantomTokenAdapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Kelp LRT withdrawal manager adapter unit test
/// @notice U:[KWM]: Unit tests for Kelp LRT withdrawal manager adapter
contract KelpLRTWithdrawalManagerAdapterUnitTest is AdapterUnitTestHelper {
    KelpLRTWithdrawalManagerAdapter adapter;

    address gateway;
    address withdrawalManager;
    address rsETH;
    address weth;
    address stETH;
    address cbETH;
    address wethPhantomToken;
    address stETHPhantomToken;
    string referralId = "test-referral";

    function setUp() public {
        _setUp();

        weth = tokens[0];
        stETH = tokens[1];
        cbETH = tokens[2];
        rsETH = tokens[3];
        withdrawalManager = makeAddr("WITHDRAWAL_MANAGER");

        gateway = address(new KelpLRTWithdrawalManagerGateway(withdrawalManager, rsETH, weth));

        wethPhantomToken = tokens[4];
        vm.mockCall(wethPhantomToken, abi.encodeWithSignature("tokenOut()"), abi.encode(weth));

        stETHPhantomToken = tokens[5];
        vm.mockCall(stETHPhantomToken, abi.encodeWithSignature("tokenOut()"), abi.encode(stETH));

        adapter = new KelpLRTWithdrawalManagerAdapter(address(creditManager), gateway, referralId);
    }

    /// @notice U:[KWM-1]: Constructor works as expected
    function test_U_KWM_01_constructor_works_as_expected() public {
        _readsTokenMask(rsETH);

        adapter = new KelpLRTWithdrawalManagerAdapter(address(creditManager), gateway, referralId);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), gateway, "Incorrect targetContract");
        assertEq(adapter.withdrawalManagerGateway(), gateway, "Incorrect withdrawalManagerGateway");
        assertEq(adapter.referralId(), referralId, "Incorrect referralId");
        assertEq(adapter.rsETH(), rsETH, "Incorrect rsETH");
    }

    /// @notice U:[KWM-2]: Wrapper functions revert on wrong caller
    function test_U_KWM_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.initiateWithdrawal(weth, 1000, "");

        _revertsOnNonFacadeCaller();
        adapter.initiateWithdrawalDiff(weth, 100);

        _revertsOnNonFacadeCaller();
        adapter.completeWithdrawal(weth, 1000, "");

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(wethPhantomToken, 1000);

        _revertsOnNonFacadeCaller();
        adapter.depositPhantomToken(wethPhantomToken, 1000);

        _revertsOnNonConfiguratorCaller();
        adapter.setTokensOutBatchStatus(new TokenOutStatus[](0));
    }

    /// @notice U:[KWM-3]: `initiateWithdrawal` works as expected
    function test_U_KWM_03_initiateWithdrawal_works_as_expected() public {
        vm.expectRevert(IKelpLRTWithdrawalManagerAdapter.TokenNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.initiateWithdrawal(weth, 1000, "");

        _setTokenOutStatus(weth, wethPhantomToken, true);

        _executesSwap({
            tokenIn: rsETH,
            callData: abi.encodeCall(IKelpLRTWithdrawalManagerGateway.initiateWithdrawal, (weth, 1000, referralId)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.initiateWithdrawal(weth, 1000, "ignored-ref-id");
        assertTrue(useSafePrices);
    }

    /// @notice U:[KWM-4]: `initiateWithdrawalDiff` works as expected
    /// @dev This test expects the correct behavior (checking rsETH balance) but the current implementation
    ///      has a bug where it checks the tokenOut balance instead. This test will fail until the bug is fixed.
    function test_U_KWM_04_initiateWithdrawalDiff_works_as_expected() public diffTestCases {
        vm.expectRevert(IKelpLRTWithdrawalManagerAdapter.TokenNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.initiateWithdrawalDiff(weth, 100);

        _setTokenOutStatus(weth, wethPhantomToken, true);

        deal({token: rsETH, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: rsETH,
            callData: abi.encodeCall(
                IKelpLRTWithdrawalManagerGateway.initiateWithdrawal, (weth, diffInputAmount, referralId)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.initiateWithdrawalDiff(weth, diffLeftoverAmount);
        assertTrue(useSafePrices);
    }

    /// @notice U:[KWM-5]: `initiateWithdrawalDiff` returns false when amount < leftoverAmount
    function test_U_KWM_05_initiateWithdrawalDiff_returns_false_when_nothing_to_withdraw() public {
        _setTokenOutStatus(weth, wethPhantomToken, true);

        deal({token: rsETH, to: creditAccount, give: 100});

        _readsActiveAccount();

        vm.prank(creditFacade);
        bool useSafePrices = adapter.initiateWithdrawalDiff(weth, 101);
        assertFalse(useSafePrices);
    }

    /// @notice U:[KWM-6]: `completeWithdrawal` works as expected
    function test_U_KWM_06_completeWithdrawal_works_as_expected() public {
        vm.expectRevert(IKelpLRTWithdrawalManagerAdapter.TokenNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.completeWithdrawal(weth, 1000, "");

        _setTokenOutStatus(weth, wethPhantomToken, true);

        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IKelpLRTWithdrawalManagerGateway.completeWithdrawal, (weth, 1000, referralId)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.completeWithdrawal(weth, 1000, "ignored-ref-id");
        assertFalse(useSafePrices);
    }

    /// @notice U:[KWM-7]: `withdrawPhantomToken` works as expected
    function test_U_KWM_07_withdrawPhantomToken_works_as_expected() public {
        vm.expectRevert(IPhantomTokenAdapter.IncorrectStakedPhantomTokenException.selector);
        vm.prank(creditFacade);
        adapter.withdrawPhantomToken(wethPhantomToken, 1000);

        _setTokenOutStatus(weth, wethPhantomToken, true);

        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IKelpLRTWithdrawalManagerGateway.completeWithdrawal, (weth, 1000, referralId)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawPhantomToken(wethPhantomToken, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[KWM-8]: `depositPhantomToken` reverts as expected
    function test_U_KWM_08_depositPhantomToken_reverts() public {
        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.depositPhantomToken(wethPhantomToken, 1000);
    }

    /// @notice U:[KWM-9]: `setTokensOutBatchStatus` works as expected
    function test_U_KWM_09_setTokensOutBatchStatus_works_as_expected() public {
        TokenOutStatus[] memory tokensOut = new TokenOutStatus[](1);

        address wrongPhantomToken = tokens[6];
        vm.mockCall(wrongPhantomToken, abi.encodeWithSignature("tokenOut()"), abi.encode(stETH)); // Returns wrong token

        tokensOut[0] = TokenOutStatus({tokenOut: weth, phantomToken: wrongPhantomToken, allowed: true});

        vm.expectRevert(IPhantomTokenAdapter.IncorrectStakedPhantomTokenException.selector);
        vm.prank(configurator);
        adapter.setTokensOutBatchStatus(tokensOut);

        tokensOut = new TokenOutStatus[](2);
        tokensOut[0] = TokenOutStatus({tokenOut: weth, phantomToken: wethPhantomToken, allowed: true});
        tokensOut[1] = TokenOutStatus({tokenOut: stETH, phantomToken: stETHPhantomToken, allowed: true});

        _readsTokenMask(weth);
        _readsTokenMask(wethPhantomToken);
        _readsTokenMask(stETH);
        _readsTokenMask(stETHPhantomToken);

        vm.prank(configurator);
        adapter.setTokensOutBatchStatus(tokensOut);

        address[] memory allowedTokens = adapter.getAllowedTokensOut();
        assertEq(allowedTokens.length, 2, "Incorrect number of allowed tokens");
        assertEq(allowedTokens[0], weth, "Incorrect first allowed token");
        assertEq(allowedTokens[1], stETH, "Incorrect second allowed token");

        assertEq(adapter.tokenOutToPhantomToken(weth), wethPhantomToken, "Incorrect weth phantom token");
        assertEq(adapter.tokenOutToPhantomToken(stETH), stETHPhantomToken, "Incorrect stETH phantom token");
        assertEq(adapter.phantomTokenToTokenOut(wethPhantomToken), weth, "Incorrect reverse mapping for weth");
        assertEq(adapter.phantomTokenToTokenOut(stETHPhantomToken), stETH, "Incorrect reverse mapping for stETH");

        tokensOut[0].allowed = false;

        vm.prank(configurator);
        adapter.setTokensOutBatchStatus(tokensOut);

        allowedTokens = adapter.getAllowedTokensOut();
        assertEq(allowedTokens.length, 1, "Incorrect number of allowed tokens after removal");
        assertEq(allowedTokens[0], stETH, "Incorrect remaining allowed token");

        assertEq(adapter.tokenOutToPhantomToken(weth), address(0), "weth phantom token not removed");
        assertEq(adapter.phantomTokenToTokenOut(wethPhantomToken), address(0), "weth reverse mapping not removed");
    }

    /// @notice U:[KWM-10]: `getAllowedTokensOut` and `getPhantomTokensForAllowedTokensOut` work as expected
    function test_U_KWM_10_getter_functions_work_as_expected() public {
        _setTokenOutStatus(weth, wethPhantomToken, true);
        _setTokenOutStatus(stETH, stETHPhantomToken, true);

        address[] memory allowedTokens = adapter.getAllowedTokensOut();
        assertEq(allowedTokens.length, 2, "Incorrect number of allowed tokens");
        assertEq(allowedTokens[0], weth, "Incorrect first allowed token");
        assertEq(allowedTokens[1], stETH, "Incorrect second allowed token");

        address[] memory phantomTokens = adapter.getPhantomTokensForAllowedTokensOut();
        assertEq(phantomTokens.length, 2, "Incorrect number of phantom tokens");
        assertEq(phantomTokens[0], wethPhantomToken, "Incorrect first phantom token");
        assertEq(phantomTokens[1], stETHPhantomToken, "Incorrect second phantom token");
    }

    /// @notice U:[KWM-11]: `serialize` works as expected
    function test_U_KWM_11_serialize_works_as_expected() public {
        _setTokenOutStatus(weth, wethPhantomToken, true);
        _setTokenOutStatus(stETH, stETHPhantomToken, true);

        bytes memory serializedData = adapter.serialize();
        (address cm, address tc, address[] memory tokens, address[] memory phantomTokens) =
            abi.decode(serializedData, (address, address, address[], address[]));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, gateway, "Incorrect targetContract in serialized data");
        assertEq(tokens.length, 2, "Incorrect number of tokens in serialized data");
        assertEq(tokens[0], weth, "Incorrect first token in serialized data");
        assertEq(tokens[1], stETH, "Incorrect second token in serialized data");
        assertEq(phantomTokens.length, 2, "Incorrect number of phantom tokens in serialized data");
        assertEq(phantomTokens[0], wethPhantomToken, "Incorrect first phantom token in serialized data");
        assertEq(phantomTokens[1], stETHPhantomToken, "Incorrect second phantom token in serialized data");
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Sets status for a token out
    function _setTokenOutStatus(address tokenOut, address phantomToken, bool allowed) internal {
        TokenOutStatus[] memory tokensOut = new TokenOutStatus[](1);
        tokensOut[0] = TokenOutStatus({tokenOut: tokenOut, phantomToken: phantomToken, allowed: allowed});

        if (allowed) {
            _readsTokenMask(tokenOut);
            _readsTokenMask(phantomToken);
        }

        vm.prank(configurator);
        adapter.setTokensOutBatchStatus(tokensOut);
    }
}
