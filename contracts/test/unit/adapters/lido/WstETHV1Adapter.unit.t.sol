// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {WstETHV1Adapter} from "../../../../adapters/lido/WstETHV1.sol";
import {IwstETH, IwstETHGetters} from "../../../../integrations/lido/IwstETH.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title wstETH v1 adapter unit test
/// @notice U:[LDO1W]: Unit tests for wstETH v1 adapter
contract WstETHV1AdapterUnitTest is AdapterUnitTestHelper {
    WstETHV1Adapter adapter;

    address stETH;
    address wstETH;

    uint256 stETHMask;
    uint256 wstETHMask;

    function setUp() public {
        _setUp();

        (stETH, stETHMask) = (tokens[0], 1);
        (wstETH, wstETHMask) = (tokens[1], 2);
        vm.mockCall(wstETH, abi.encodeCall(IwstETHGetters.stETH, ()), abi.encode(stETH));

        adapter = new WstETHV1Adapter(address(creditManager), wstETH);
    }

    /// @notice U:[LDO1W-1]: Constructor works as expected
    function test_U_LDO1W_01_constructor_works_as_expected() public {
        _readsTokenMask(stETH);
        _readsTokenMask(wstETH);
        adapter = new WstETHV1Adapter(address(creditManager), wstETH);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), wstETH, "Incorrect targetContract");
        assertEq(adapter.stETH(), stETH, "Incorrect stETH");
        assertEq(adapter.stETHTokenMask(), stETHMask, "Incorrect stETHMask");
        assertEq(adapter.wstETHTokenMask(), wstETHMask, "Incorrect wstETHMask");
    }

    /// @notice U:[LDO1W-2]: Wrapper functions revert on wrong caller
    function test_U_LDO1W_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.wrap(0);

        _revertsOnNonFacadeCaller();
        adapter.wrapDiff(0);

        _revertsOnNonFacadeCaller();
        adapter.unwrap(0);

        _revertsOnNonFacadeCaller();
        adapter.unwrapDiff(0);
    }

    /// @notice U:[LDO1W-3]: `wrap` works as expected
    function test_U_LDO1W_03_wrap_works_as_expected() public {
        _executesSwap({
            tokenIn: stETH,
            tokenOut: wstETH,
            callData: abi.encodeCall(IwstETH.wrap, (1000)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.wrap(1000);

        assertEq(tokensToEnable, wstETHMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[LDO1W-4]: `wrapDiff` works as expected
    function test_U_LDO1W_04_wrapDiff_works_as_expected() public diffTestCases {
        deal({token: stETH, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: stETH,
            tokenOut: wstETH,
            callData: abi.encodeCall(IwstETH.wrap, (diffInputAmount)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.wrapDiff(diffLeftoverAmount);

        assertEq(tokensToEnable, wstETHMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? stETHMask : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[LDO1W-5]: `unwrap` works as expected
    function test_U_LDO1W_05_unwrap_works_as_expected() public {
        _executesSwap({
            tokenIn: wstETH,
            tokenOut: stETH,
            callData: abi.encodeCall(IwstETH.unwrap, (1000)),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.unwrap(1000);

        assertEq(tokensToEnable, stETHMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[LDO1W-6]: `unwrapDiff` works as expected
    function test_U_LDO1W_06_unwrapDiff_works_as_expected() public diffTestCases {
        deal({token: wstETH, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: wstETH,
            tokenOut: stETH,
            callData: abi.encodeCall(IwstETH.unwrap, (diffInputAmount)),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.unwrapDiff(diffLeftoverAmount);

        assertEq(tokensToEnable, stETHMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? wstETHMask : 0, "Incorrect tokensToDisable");
    }
}
