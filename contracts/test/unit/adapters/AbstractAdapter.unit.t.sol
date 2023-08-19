// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {TestHelper} from "@gearbox-protocol/core-v3/contracts/test/lib/helper.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";
import {
    CallerNotCreditFacadeException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {CreditManagerMock, CreditManagerMockEvents} from "../../mocks/credit/CreditManagerMock.sol";

import {AbstractAdapterHarness} from "./AbstractAdapterHarness.sol";

/// @title Abstract adapter unit test
/// @notice U:[AA]: `AbstractAdapter` unit tests
contract AbstractAdapterUnitTest is TestHelper, CreditManagerMockEvents {
    AbstractAdapterHarness abstractAdapter;
    AddressProviderV3ACLMock addressProvider;
    CreditManagerMock creditManager;

    address facade;
    address target;

    function setUp() public {
        facade = makeAddr("CREDIT_FACADE");
        target = makeAddr("TARGET_CONTRACT");

        addressProvider = new AddressProviderV3ACLMock();
        creditManager = new CreditManagerMock(address(addressProvider), facade);
        abstractAdapter = new AbstractAdapterHarness(address(creditManager), target);
    }

    /// @notice U:[AA-1A]: constructor reverts on zero address
    function test_U_AA_01A_constructor_reverts_on_zero_address() public {
        vm.expectRevert();
        new AbstractAdapterHarness(address(0), address(0));

        vm.expectRevert(ZeroAddressException.selector);
        new AbstractAdapterHarness(address(creditManager), address(0));
    }

    /// @notice U:[AA-1B]: constructor sets correct values
    function test_U_AA_01B_constructor_sets_correct_values() public {
        assertEq(abstractAdapter.creditManager(), address(creditManager), "Incorrect credit manager");
        assertEq(abstractAdapter.addressProvider(), address(addressProvider), "Incorrect address provider");
        assertEq(abstractAdapter.targetContract(), target, "Incorrect target contract");
    }

    /// @notice U:[AA-2]: `_revertIfCallerNotCreditFacade` works correctly
    function test_U_AA_02_revertIfCallerNotCreditFacade_works_correctly(address caller) public {
        vm.assume(caller != facade);

        vm.expectRevert(CallerNotCreditFacadeException.selector);
        vm.prank(caller);
        abstractAdapter.revertIfCallerNotCreditFacade();
    }

    /// @notice U:[AA-3]: `_creditAccount` works correctly
    function test_U_AA_03_creditAccount_works_correctly(address creditAccount) public {
        creditManager.setActiveCreditAccount(creditAccount);

        vm.expectCall(address(creditManager), abi.encodeCall(creditManager.getActiveCreditAccountOrRevert, ()));
        assertEq(abstractAdapter.creditAccount(), creditAccount, "Incorrect external call credit account");
    }

    /// @notice U:[AA-4]: `_getMaskOrRevert` works correctly
    function test_U_AA_04_getMaskOrRevert_works_correctly(address token, uint8 index) public {
        uint256 mask = 1 << index;
        creditManager.setMask(token, mask);

        vm.expectCall(address(creditManager), abi.encodeCall(creditManager.getTokenMaskOrRevert, (token)));
        assertEq(abstractAdapter.getMaskOrRevert(token), mask, "Incorrect token mask");
    }

    /// @notice U:[AA-5]: `_approveToken` works correctly
    function test_U_AA_05_approveToken_works_correctly(address token, uint256 amount) public {
        vm.expectCall(address(creditManager), abi.encodeCall(creditManager.approveCreditAccount, (token, amount)));
        abstractAdapter.approveToken(token, amount);
    }

    /// @notice U:[AA-6]: `_execute` works correctly
    function test_U_AA_06_execute_works_correctly(bytes memory data, bytes memory expectedResult) public {
        creditManager.setExecuteResult(expectedResult);

        vm.expectCall(address(creditManager), abi.encodeCall(creditManager.execute, (data)));
        assertEq(abstractAdapter.execute(data), expectedResult, "Incorrect result");
    }

    /// @notice U:[AA-7]: `_executeSwapNoApprove` works correctly
    function test_U_AA_07_executeSwapNoApprove_works_correctly(
        address tokenIn,
        address tokenOut,
        uint8 tokenInIndex,
        uint8 tokenOutIndex,
        bytes memory data,
        bytes memory expectedResult
    ) public {
        if (tokenIn == tokenOut) tokenOutIndex = tokenInIndex;
        creditManager.setMask(tokenIn, 1 << tokenInIndex);
        creditManager.setMask(tokenOut, 1 << tokenOutIndex);
        creditManager.setExecuteResult(expectedResult);

        uint256 snapshot = vm.snapshot();
        for (uint256 caseNumber; caseNumber < 2; ++caseNumber) {
            bool disableTokenIn = caseNumber == 1;
            string memory caseName = caseNumber == 1 ? "disableTokenIn = true" : "disableTokenIn = false";

            vm.expectEmit(false, false, false, false);
            emit Execute();

            (uint256 tokensToEnable, uint256 tokensToDisable, bytes memory result) =
                abstractAdapter.executeSwapNoApprove(tokenIn, tokenOut, data, disableTokenIn);

            assertEq(tokensToEnable, 1 << tokenOutIndex, _testCaseErr(caseName, "Incorrect tokensToEnable"));
            assertEq(
                tokensToDisable,
                disableTokenIn ? 1 << tokenInIndex : 0,
                _testCaseErr(caseName, "Incorrect tokensToDisable")
            );
            assertEq(result, expectedResult, _testCaseErr(caseName, "Incorrect result"));

            vm.revertTo(snapshot);
        }
    }

    /// @notice U:[AA-8]: `_executeSwapSafeApprove` works correctly
    function test_U_AA_08_executeSwapSafeApprove_works_correctly(
        address tokenIn,
        address tokenOut,
        uint8 tokenInIndex,
        uint8 tokenOutIndex,
        bytes memory data,
        bytes memory expectedResult
    ) public {
        if (tokenIn == tokenOut) tokenOutIndex = tokenInIndex;
        creditManager.setMask(tokenIn, 1 << tokenInIndex);
        creditManager.setMask(tokenOut, 1 << tokenOutIndex);
        creditManager.setExecuteResult(expectedResult);

        uint256 snapshot = vm.snapshot();
        for (uint256 caseNumber; caseNumber < 2; ++caseNumber) {
            bool disableTokenIn = caseNumber == 1;
            string memory caseName = caseNumber == 1 ? "disableTokenIn = true" : "disableTokenIn = false";

            // need to ensure that order is correct
            vm.expectEmit(true, false, false, true);
            emit Approve(tokenIn, type(uint256).max);
            vm.expectEmit(false, false, false, false);
            emit Execute();
            vm.expectEmit(true, false, false, true);
            emit Approve(tokenIn, 1);

            (uint256 tokensToEnable, uint256 tokensToDisable, bytes memory result) =
                abstractAdapter.executeSwapSafeApprove(tokenIn, tokenOut, data, disableTokenIn);

            assertEq(tokensToEnable, 1 << tokenOutIndex, _testCaseErr(caseName, "Incorrect tokensToEnable"));
            assertEq(
                tokensToDisable,
                disableTokenIn ? 1 << tokenInIndex : 0,
                _testCaseErr(caseName, "Incorrect tokensToDisable")
            );
            assertEq(result, expectedResult, _testCaseErr(caseName, "Incorrect result"));

            vm.revertTo(snapshot);
        }
    }
}
