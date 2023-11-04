// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {YearnV2Adapter} from "../../../../adapters/yearn/YearnV2.sol";
import {IYVault} from "../../../../integrations/yearn/IYVault.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Yearn v2 adapter unit test
/// @notice U:[YFI2]: Unit tests for Yearn v2 yToken adapter
contract YearnV2AdapterUnitTest is AdapterUnitTestHelper {
    YearnV2Adapter adapter;

    address token;
    address yToken;

    uint256 tokenMask;
    uint256 yTokenMask;

    function setUp() public {
        _setUp();

        (token, tokenMask) = (tokens[0], 1);
        (yToken, yTokenMask) = (tokens[1], 2);
        vm.mockCall(yToken, abi.encodeCall(IYVault.token, ()), abi.encode(token));

        adapter = new YearnV2Adapter(address(creditManager), yToken);
    }

    /// @notice U:[YFI2-1]: Constructor works as expected
    function test_U_YFI2_01_constructor_works_as_expected() public {
        _readsTokenMask(token);
        _readsTokenMask(yToken);
        adapter = new YearnV2Adapter(address(creditManager), yToken);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), yToken, "Incorrect targetContract");
        assertEq(adapter.token(), token, "Incorrect token");
        assertEq(adapter.tokenMask(), tokenMask, "Incorrect tokenMask");
        assertEq(adapter.yTokenMask(), yTokenMask, "Incorrect yTokenMask");
    }

    /// @notice U:[YFI2-2]: Wrapper functions revert on wrong caller
    function test_U_YFI2_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.depositDiff(0);

        _revertsOnNonFacadeCaller();
        adapter.deposit(0);

        _revertsOnNonFacadeCaller();
        adapter.deposit(0, address(0));

        _revertsOnNonFacadeCaller();
        adapter.withdrawDiff(0);

        _revertsOnNonFacadeCaller();
        adapter.withdraw(0);

        _revertsOnNonFacadeCaller();
        adapter.withdraw(0, address(0));

        _revertsOnNonFacadeCaller();
        adapter.withdraw(0, address(0), 0);
    }

    /// @notice U:[YFI2-3]: `depositDiff()` works as expected
    function test_U_YFI2_03_depositDiff_works_as_expected() public diffTestCases {
        deal({token: token, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: token,
            tokenOut: yToken,
            callData: abi.encodeWithSignature("deposit(uint256)", diffInputAmount),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.depositDiff(diffLeftoverAmount);

        assertEq(tokensToEnable, yTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? tokenMask : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[YFI2-4]: `deposit(uint256)` works as expected
    function test_U_YFI2_04_deposit_uint256_works_as_expected() public {
        _executesSwap({
            tokenIn: token,
            tokenOut: yToken,
            callData: abi.encodeWithSignature("deposit(uint256)", 1000),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.deposit(1000);

        assertEq(tokensToEnable, yTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[YFI2-5]: `deposit(uint256,address)` works as expected
    function test_U_YFI2_05_deposit_uint256_address_works_as_expected() public {
        _executesSwap({
            tokenIn: token,
            tokenOut: yToken,
            callData: abi.encodeWithSignature("deposit(uint256)", 1000),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.deposit(1000, address(0));

        assertEq(tokensToEnable, yTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[YFI2-6]: `withdrawDiff()` works as expected
    function test_U_YFI2_06_withdrawDiff_works_as_expected() public diffTestCases {
        deal({token: yToken, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: yToken,
            tokenOut: token,
            callData: abi.encodeWithSignature("withdraw(uint256)", diffInputAmount),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawDiff(diffLeftoverAmount);

        assertEq(tokensToEnable, tokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? yTokenMask : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[YFI2-7]: `withdraw(uint256)` works as expected
    function test_U_YFI2_07_withdraw_uint256_works_as_expected() public {
        _executesSwap({
            tokenIn: yToken,
            tokenOut: token,
            callData: abi.encodeWithSignature("withdraw(uint256)", 1000),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdraw(1000);

        assertEq(tokensToEnable, tokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[YFI2-8]: `withdraw(uint256,address)` works as expected
    function test_U_YFI2_08_withdraw_uint256_address_works_as_expected() public {
        _executesSwap({
            tokenIn: yToken,
            tokenOut: token,
            callData: abi.encodeWithSignature("withdraw(uint256)", 1000),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdraw(1000, address(0));

        assertEq(tokensToEnable, tokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[YFI2-9]: `withdraw(uint256,address,uint256)` works as expected
    function test_U_YFI2_09_withdraw_uint256_address_uint256_works_as_expected() public {
        _readsActiveAccount();
        _executesSwap({
            tokenIn: yToken,
            tokenOut: token,
            callData: abi.encodeWithSignature("withdraw(uint256,address,uint256)", 1000, creditAccount, 10),
            requiresApproval: false,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdraw(1000, address(0), 10);

        assertEq(tokensToEnable, tokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }
}
