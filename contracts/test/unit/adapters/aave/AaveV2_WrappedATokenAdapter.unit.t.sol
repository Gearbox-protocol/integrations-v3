// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {AaveV2_WrappedATokenAdapter} from "../../../../adapters/aave/AaveV2_WrappedATokenAdapter.sol";
import {WrappedAToken} from "../../../../helpers/aave/AaveV2_WrappedAToken.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Aave v2 wrapped aToken adapter unit test
/// @notice U:[AAVE2W]: Unit tests for Aave v2 waToken adapter
contract AaveV2_WrappedATokenAdapterUnitTest is AdapterUnitTestHelper {
    AaveV2_WrappedATokenAdapter adapter;

    address token;
    address aToken;
    address waToken;

    uint256 tokenMask;
    uint256 aTokenMask;
    uint256 waTokenMask;

    function setUp() public {
        _setUp();

        (token, tokenMask) = (tokens[0], 1);
        (aToken, aTokenMask) = (tokens[1], 2);
        (waToken, waTokenMask) = (tokens[2], 4);

        vm.mockCall(waToken, abi.encodeWithSignature("aToken()"), abi.encode(aToken));
        vm.mockCall(waToken, abi.encodeWithSignature("underlying()"), abi.encode(token));

        adapter = new AaveV2_WrappedATokenAdapter(address(creditManager), waToken);
    }

    /// @notice U:[AAVE2W-1]: Constructor works as expected
    function test_U_AAVE2W_01_constructor_works_as_expected() public {
        _readsTokenMask(token);
        _readsTokenMask(aToken);
        _readsTokenMask(waToken);
        adapter = new AaveV2_WrappedATokenAdapter(address(creditManager), waToken);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), waToken, "Incorrect targetContract");
        assertEq(adapter.underlying(), token, "Incorrect underlying");
        assertEq(adapter.aToken(), aToken, "Incorrect aToken");
        assertEq(adapter.tokenMask(), tokenMask, "Incorrect tokenMask");
        assertEq(adapter.aTokenMask(), aTokenMask, "Incorrect aTokenMask");
        assertEq(adapter.waTokenMask(), waTokenMask, "Incorrect waTokenMask");
    }

    /// @notice U:[AAVE2W-2]: Wrapper functions revert on wrong caller
    function test_U_AAVE2W_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.deposit(0);

        _revertsOnNonFacadeCaller();
        adapter.depositDiff(0);

        _revertsOnNonFacadeCaller();
        adapter.depositAll();

        _revertsOnNonFacadeCaller();
        adapter.depositUnderlying(0);

        _revertsOnNonFacadeCaller();
        adapter.depositDiffUnderlying(0);

        _revertsOnNonFacadeCaller();
        adapter.depositAllUnderlying();

        _revertsOnNonFacadeCaller();
        adapter.withdraw(0);

        _revertsOnNonFacadeCaller();
        adapter.withdrawDiff(0);

        _revertsOnNonFacadeCaller();
        adapter.withdrawAll();

        _revertsOnNonFacadeCaller();
        adapter.withdrawUnderlying(0);

        _revertsOnNonFacadeCaller();
        adapter.withdrawDiffUnderlying(0);

        _revertsOnNonFacadeCaller();
        adapter.withdrawAllUnderlying();
    }

    /// @notice U:[AAVE2W-3]: `deposit` works as expected
    function test_U_AAVE2W_03_deposit_works_as_expected() public {
        _executesSwap({
            tokenIn: aToken,
            tokenOut: waToken,
            callData: abi.encodeCall(WrappedAToken.deposit, (123)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.deposit(123);

        assertEq(tokensToEnable, waTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2W-4]: `depositAll` works as expected
    function test_U_AAVE2W_04_depositAll_works_as_expected() public {
        deal({token: aToken, to: creditAccount, give: 1001});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: aToken,
            tokenOut: waToken,
            callData: abi.encodeCall(WrappedAToken.deposit, (1000)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.depositAll();

        assertEq(tokensToEnable, waTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, aTokenMask, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2-4A]: `depositDiff` works as expected
    function test_U_AAVE2_04A_depositDiff_works_as_expected() public diffTestCases {
        deal({token: aToken, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: aToken,
            tokenOut: waToken,
            callData: abi.encodeCall(WrappedAToken.deposit, (diffInputAmount)),
            requiresApproval: true,
            validatesTokens: false
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.depositDiff(diffLeftoverAmount);

        assertEq(tokensToEnable, waTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? aTokenMask : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2W-5]: `depositUnderlying` works as expected
    function test_U_AAVE2W_05_depositUnderlying_works_as_expected() public {
        _executesSwap({
            tokenIn: token,
            tokenOut: waToken,
            callData: abi.encodeCall(WrappedAToken.depositUnderlying, (123)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.depositUnderlying(123);

        assertEq(tokensToEnable, waTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2W-6]: `depositAllUnderlying` works as expected
    function test_U_AAVE2W_06_depositAllUnderlying_works_as_expected() public {
        deal({token: token, to: creditAccount, give: 1001});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: token,
            tokenOut: waToken,
            callData: abi.encodeCall(WrappedAToken.depositUnderlying, (1000)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.depositAllUnderlying();

        assertEq(tokensToEnable, waTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, tokenMask, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2-6A]: `depositDiffUnderlying` works as expected
    function test_U_AAVE2_06A_depositDiffUnderlying_works_as_expected() public diffTestCases {
        deal({token: token, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: token,
            tokenOut: waToken,
            callData: abi.encodeCall(WrappedAToken.depositUnderlying, (diffInputAmount)),
            requiresApproval: true,
            validatesTokens: false
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.depositDiffUnderlying(diffLeftoverAmount);

        assertEq(tokensToEnable, waTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? tokenMask : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2W-7]: `withdraw` works as expected
    function test_U_AAVE2W_07_withdraw_works_as_expected() public {
        _executesSwap({
            tokenIn: waToken,
            tokenOut: aToken,
            callData: abi.encodeCall(WrappedAToken.withdraw, (123)),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdraw(123);

        assertEq(tokensToEnable, aTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2W-8]: `withdrawAll` works as expected
    function test_U_AAVE2W_08_withdrawAll_works_as_expected() public {
        deal({token: waToken, to: creditAccount, give: 1001});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: waToken,
            tokenOut: aToken,
            callData: abi.encodeCall(WrappedAToken.withdraw, (1000)),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawAll();

        assertEq(tokensToEnable, aTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, waTokenMask, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2-8A]: `withdrawDiff` works as expected
    function test_U_AAVE2_08A_withdrawDiff_works_as_expected() public diffTestCases {
        deal({token: waToken, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: waToken,
            tokenOut: aToken,
            callData: abi.encodeCall(WrappedAToken.withdraw, (diffInputAmount)),
            requiresApproval: false,
            validatesTokens: false
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawDiff(diffLeftoverAmount);

        assertEq(tokensToEnable, aTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? waTokenMask : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2W-9]: `withdrawUnderlying` works as expected
    function test_U_AAVE2W_09_withdrawUnderlying_works_as_expected() public {
        _executesSwap({
            tokenIn: waToken,
            tokenOut: token,
            callData: abi.encodeCall(WrappedAToken.withdrawUnderlying, (123)),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawUnderlying(123);

        assertEq(tokensToEnable, tokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2W-10]: `withdrawAllUnderlying` works as expected
    function test_U_AAVE2W_10_withdrawAllUnderlying_works_as_expected() public {
        deal({token: waToken, to: creditAccount, give: 1001});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: waToken,
            tokenOut: token,
            callData: abi.encodeCall(WrappedAToken.withdrawUnderlying, (1000)),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawAllUnderlying();

        assertEq(tokensToEnable, tokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, waTokenMask, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2-10A]: `withdrawDiffUnderlying` works as expected
    function test_U_AAVE2_10A_withdrawDiffUnderlying_works_as_expected() public diffTestCases {
        deal({token: waToken, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: waToken,
            tokenOut: token,
            callData: abi.encodeCall(WrappedAToken.withdrawUnderlying, (diffInputAmount)),
            requiresApproval: false,
            validatesTokens: false
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawDiffUnderlying(diffLeftoverAmount);

        assertEq(tokensToEnable, tokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? waTokenMask : 0, "Incorrect tokensToDisable");
    }
}
