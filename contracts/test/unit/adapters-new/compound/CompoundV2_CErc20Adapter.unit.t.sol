// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {CompoundV2_CErc20Adapter} from "../../../../adapters/compound/CompoundV2_CErc20Adapter.sol";
import {ICErc20, ICErc20Actions} from "../../../../integrations/compound/ICErc20.sol";
import {ICompoundV2_Exceptions} from "../../../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Compound v2 CErc20 adapter unit test
/// @notice U:[COMP2T]: Unit tests for Compound v2 CErc20 token adapter
contract CompoundV2_CErc20AdapterUnitTest is AdapterUnitTestHelper, ICompoundV2_Exceptions {
    CompoundV2_CErc20Adapter adapter;

    address token;
    address cToken;

    uint256 tokenMask;
    uint256 cTokenMask;

    function setUp() public {
        _setUp();

        creditManager.setExecuteResult(abi.encode(0));

        (token, tokenMask) = (tokens[0], 1);
        (cToken, cTokenMask) = (tokens[1], 2);
        vm.mockCall(cToken, abi.encodeCall(ICErc20.underlying, ()), abi.encode(token));

        adapter = new CompoundV2_CErc20Adapter(address(creditManager), cToken);
    }

    /// @notice U:[COMP2T-1]: Constructor works as expected
    function test_U_COMP2T_01_constructor_works_as_expected() public {
        _readsTokenMask(token);
        _readsTokenMask(cToken);
        adapter = new CompoundV2_CErc20Adapter(address(creditManager), cToken);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), cToken, "Incorrect targetContract");
        assertEq(adapter.cToken(), cToken, "Incorrect cToken");
        assertEq(adapter.underlying(), token, "Incorrect underlying");
        assertEq(adapter.tokenMask(), tokenMask, "Incorrect tokenMask");
        assertEq(adapter.cTokenMask(), cTokenMask, "Incorrect cTokenMask");
    }

    /// @notice U:[COMP2T-2]: Wrapper functions revert on wrong caller
    function test_U_COMP2T_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.mint(0);

        _revertsOnNonFacadeCaller();
        adapter.mintAll();

        _revertsOnNonFacadeCaller();
        adapter.redeem(0);

        _revertsOnNonFacadeCaller();
        adapter.redeemAll();

        _revertsOnNonFacadeCaller();
        adapter.redeemUnderlying(0);
    }

    /// @notice U:[COMP2T-3]: Wrapper functions revert on cToken error
    function test_U_COMP2T_03_wrapper_functions_revert_on_cToken_error() public {
        creditManager.setExecuteResult(abi.encode(1));
        deal({token: token, to: creditAccount, give: 2});
        deal({token: cToken, to: creditAccount, give: 2});

        vm.expectRevert(abi.encodeWithSelector(CTokenError.selector, 1));
        vm.prank(creditFacade);
        adapter.mint(1);

        vm.expectRevert(abi.encodeWithSelector(CTokenError.selector, 1));
        vm.prank(creditFacade);
        adapter.mintAll();

        vm.expectRevert(abi.encodeWithSelector(CTokenError.selector, 1));
        vm.prank(creditFacade);
        adapter.redeem(1);

        vm.expectRevert(abi.encodeWithSelector(CTokenError.selector, 1));
        vm.prank(creditFacade);
        adapter.redeemAll();

        vm.expectRevert(abi.encodeWithSelector(CTokenError.selector, 1));
        vm.prank(creditFacade);
        adapter.redeemUnderlying(1);
    }

    /// @notice U:[COMP2T-4]: `mint` works as expected
    function test_U_COMP2T_04_mint_works_as_expected() public {
        _executesSwap({
            tokenIn: token,
            tokenOut: cToken,
            callData: abi.encodeCall(ICErc20Actions.mint, (1000)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.mint(1000);

        assertEq(tokensToEnable, cTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[COMP2T-5]: `mintAll` works as expected
    function test_U_COMP2T_05_mintAll_works_as_expected() public {
        deal({token: token, to: creditAccount, give: 1001});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: token,
            tokenOut: cToken,
            callData: abi.encodeCall(ICErc20Actions.mint, (1000)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.mintAll();

        assertEq(tokensToEnable, cTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, tokenMask, "Incorrect tokensToDisable");
    }

    /// @notice U:[COMP2T-6]: `redeem` works as expected
    function test_U_COMP2T_06_redeem_works_as_expected() public {
        _executesSwap({
            tokenIn: cToken,
            tokenOut: token,
            callData: abi.encodeCall(ICErc20Actions.redeem, (1000)),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.redeem(1000);

        assertEq(tokensToEnable, tokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[COMP2T-7]: `redeemAll` works as expected
    function test_U_COMP2T_07_redeemAll_works_as_expected() public {
        deal({token: cToken, to: creditAccount, give: 1001});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: cToken,
            tokenOut: token,
            callData: abi.encodeCall(ICErc20Actions.redeem, (1000)),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.redeemAll();

        assertEq(tokensToEnable, tokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, cTokenMask, "Incorrect tokensToDisable");
    }

    /// @notice U:[COMP2T-8]: `redeemUnderlying` works as expected
    function test_U_COMP2T_08_redeemUnderlying_works_as_expected() public {
        _executesSwap({
            tokenIn: cToken,
            tokenOut: token,
            callData: abi.encodeCall(ICErc20Actions.redeemUnderlying, (1000)),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.redeemUnderlying(1000);

        assertEq(tokensToEnable, tokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }
}
