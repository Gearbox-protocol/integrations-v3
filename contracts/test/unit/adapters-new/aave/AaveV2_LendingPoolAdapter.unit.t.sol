// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {AaveV2_LendingPoolAdapter} from "../../../../adapters/aave/AaveV2_LendingPoolAdapter.sol";
import {ILendingPool, DataTypes} from "../../../../integrations/aave/ILendingPool.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Aave v2 lending pool adapter unit test
/// @notice U:[AAVE2]: Unit tests for Aave v2 lending pool adapter
contract AaveV2_LendingPoolAdapterUnitTest is AdapterUnitTestHelper {
    AaveV2_LendingPoolAdapter adapter;

    address lendingPool;

    function setUp() public {
        _setUp();

        lendingPool = makeAddr("LENDING_POOL");

        DataTypes.ReserveData memory data;
        data.aTokenAddress = tokens[1];
        vm.mockCall(lendingPool, abi.encodeCall(ILendingPool.getReserveData, (tokens[0])), abi.encode(data));

        adapter = new AaveV2_LendingPoolAdapter(address(creditManager), lendingPool);
    }

    /// @notice U:[AAVE2-1]: Constructor works as expected
    function test_U_AAVE2_01_constructor_works_as_expected() public {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), lendingPool, "Incorrect targetContract");
    }

    /// @notice U:[AAVE2-2]: Wrapper functions revert on wrong caller
    function test_U_AAVE2_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.deposit(address(0), 0, address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.depositAll(address(0));

        _revertsOnNonFacadeCaller();
        adapter.withdraw(address(0), 0, address(0));

        _revertsOnNonFacadeCaller();
        adapter.withdrawAll(address(0));
    }

    /// @notice U:[AAVE2-3]: `deposit` works as expected
    function test_U_AAVE2_03_deposit_works_as_expected() public {
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(ILendingPool.deposit, (tokens[0], 123, creditAccount, 0)),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.deposit(tokens[0], 123, address(0), 0);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2-4]: `depositAll` works as expected
    function test_U_AAVE2_04_depositAll_works_as_expected() public {
        deal({token: tokens[0], to: creditAccount, give: 1001});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(ILendingPool.deposit, (tokens[0], 1000, creditAccount, 0)),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.depositAll(tokens[0]);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 1, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2-5A]: `withdraw` works as expected
    function test_U_AAVE2_05A_withdraw_works_as_expected() public {
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[1],
            tokenOut: tokens[0],
            callData: abi.encodeCall(ILendingPool.withdraw, (tokens[0], 123, creditAccount)),
            requiresApproval: false,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdraw(tokens[0], 123, address(0));

        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2-5B]: `withdraw` works as expected with amx amount
    function test_U_AAVE2_05B_withdraw_works_as_expected_with_max_amount() public {
        deal({token: tokens[1], to: creditAccount, give: 1001});
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[1],
            tokenOut: tokens[0],
            callData: abi.encodeCall(ILendingPool.withdraw, (tokens[0], 1000, creditAccount)),
            requiresApproval: false,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdraw(tokens[0], type(uint256).max, address(0));

        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 2, "Incorrect tokensToDisable");
    }

    /// @notice U:[AAVE2-6]: `withdrawAll` works as expected
    function test_U_AAVE2_06_withdrawAll_works_as_expected() public {
        deal({token: tokens[1], to: creditAccount, give: 1001});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[1],
            tokenOut: tokens[0],
            callData: abi.encodeCall(ILendingPool.withdraw, (tokens[0], 1000, creditAccount)),
            requiresApproval: false,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.withdrawAll(tokens[0]);

        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 2, "Incorrect tokensToDisable");
    }
}
