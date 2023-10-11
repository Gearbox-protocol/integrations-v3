// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {WstETHV1Adapter} from "../../../../adapters/lido/WstETHV1.sol";
import {IwstETH, IwstETHGetters} from "../../../../integrations/lido/IwstETH.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title wstETH v1 adapter unit test
/// @notice U:[WST]: Unit tests for wstETH v1 adapter
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

    /// @notice U:[WST-1]: Constructor works as expected
    function test_U_WST_01_constructor_works_as_expected() public {
        _readsTokenMask(stETH);
        _readsTokenMask(wstETH);
        adapter = new WstETHV1Adapter(address(creditManager), wstETH);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), wstETH, "Incorrect targetContract");
        assertEq(adapter.stETH(), stETH, "Incorrect stETH");
        assertEq(adapter.stETHTokenMask(), stETHMask, "Incorrect stETHMask");
        assertEq(adapter.wstETHTokenMask(), wstETHMask, "Incorrect wstETHMask");
    }

    /// @notice U:[WST-2]: Wrapper functions revert on wrong caller
    function test_U_WST_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.wrap(0);

        _revertsOnNonFacadeCaller();
        adapter.wrapAll();

        _revertsOnNonFacadeCaller();
        adapter.unwrap(0);

        _revertsOnNonFacadeCaller();
        adapter.unwrapAll();
    }

    /// @notice U:[WST-3]: `wrap` works as expected
    function test_U_WST_03_wrap_works_as_expected() public {
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

    /// @notice U:[WST-4]: `wrapAll` works as expected
    function test_U_WST_04_wrapAll_works_as_expected() public {
        deal({token: stETH, to: creditAccount, give: 1000});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: stETH,
            tokenOut: wstETH,
            callData: abi.encodeCall(IwstETH.wrap, (999)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.wrapAll();

        assertEq(tokensToEnable, wstETHMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, stETHMask, "Incorrect tokensToDisable");
    }

    /// @notice U:[WST-5]: `unwrap` works as expected
    function test_U_WST_05_unwrap_works_as_expected() public {
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

    /// @notice U:[WST-6]: `unwrapAll` works as expected
    function test_U_WST_06_unwrapAll_works_as_expected() public {
        deal({token: wstETH, to: creditAccount, give: 1000});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: wstETH,
            tokenOut: stETH,
            callData: abi.encodeCall(IwstETH.unwrap, (999)),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.unwrapAll();

        assertEq(tokensToEnable, stETHMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, wstETHMask, "Incorrect tokensToDisable");
    }
}
