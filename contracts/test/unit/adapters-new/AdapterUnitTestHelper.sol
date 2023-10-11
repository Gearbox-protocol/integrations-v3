// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {
    CallerNotConfiguratorException,
    CallerNotCreditFacadeException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {CreditManagerMock, CreditManagerMockEvents} from "../../mocks/credit/CreditManagerMock.sol";

contract AdapterUnitTestHelper is Test, CreditManagerMockEvents {
    address configurator;
    address creditFacade;
    address creditAccount;
    CreditManagerMock creditManager;
    AddressProviderV3ACLMock addressProvider;

    address[8] tokens;

    function _setUp() internal {
        configurator = makeAddr("CONFIGURATOR");
        creditFacade = makeAddr("CREDIT_FACADE");
        creditAccount = makeAddr("CREDIT_ACCOUNT");

        vm.prank(configurator);
        addressProvider = new AddressProviderV3ACLMock();

        creditManager = new CreditManagerMock(address(addressProvider), creditFacade);

        for (uint256 i; i < tokens.length; ++i) {
            string memory name = string.concat("Test Token ", vm.toString(i));
            string memory symbol = string.concat("TEST", vm.toString(i));
            tokens[i] = address(new ERC20Mock(name, symbol, 18));
            creditManager.setMask(tokens[i], 1 << i);
        }

        creditManager.setActiveCreditAccount(creditAccount);
    }

    function _revertsOnNonConfiguratorCaller() internal {
        vm.expectRevert(CallerNotConfiguratorException.selector);
    }

    function _revertsOnNonFacadeCaller() internal {
        vm.expectRevert(CallerNotCreditFacadeException.selector);
    }

    function _readsTokenMask(address token) internal {
        vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.getTokenMaskOrRevert, (token)));
    }

    function _readsActiveAccount() internal {
        vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.getActiveCreditAccountOrRevert, ()));
    }

    function _executesSwap(
        address tokenIn,
        address tokenOut,
        bytes memory callData,
        bool requiresApproval,
        bool validatesTokens
    ) internal {
        if (validatesTokens) {
            vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.getTokenMaskOrRevert, (tokenOut)));

            if (!requiresApproval) {
                vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.getTokenMaskOrRevert, (tokenIn)));
            }
        }

        if (requiresApproval) {
            vm.expectCall(
                address(creditManager),
                abi.encodeCall(ICreditManagerV3.approveCreditAccount, (tokenIn, type(uint256).max))
            );

            vm.expectEmit(false, false, false, true, address(creditManager));
            emit Approve(tokenIn, type(uint256).max);
        }

        vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.execute, (callData)));
        vm.expectEmit(false, false, false, false, address(creditManager));
        emit Execute();

        if (requiresApproval) {
            vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.approveCreditAccount, (tokenIn, 1)));
            vm.expectEmit(false, false, false, true, address(creditManager));
            emit Approve(tokenIn, 1);
        }
    }
}
