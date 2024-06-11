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

import {CreditManagerV3Mock, CreditManagerV3MockEvents} from "../../mocks/credit/CreditManagerV3Mock.sol";

contract AdapterUnitTestHelper is Test, CreditManagerV3MockEvents {
    address configurator;
    address creditFacade;
    address creditAccount;
    address creditConfigurator;
    address pool;
    address acl;
    CreditManagerV3Mock creditManager;

    address[10] tokens;

    uint256 diffMintedAmount = 1001;
    uint256 diffLeftoverAmount;
    uint256 diffInputAmount;
    bool diffDisableTokenIn;

    function _setUp() internal {
        configurator = makeAddr("CONFIGURATOR");
        creditFacade = makeAddr("CREDIT_FACADE");
        creditAccount = makeAddr("CREDIT_ACCOUNT");
        creditConfigurator = makeAddr("CREDIT_CONFIGURATOR");
        pool = makeAddr("POOL");

        vm.prank(configurator);
        acl = address(new AddressProviderV3ACLMock());

        vm.mockCall(pool, abi.encodeWithSignature("acl()"), abi.encode(acl));

        creditManager = new CreditManagerV3Mock(pool, creditFacade, creditConfigurator);

        for (uint256 i; i < tokens.length; ++i) {
            string memory name = string.concat("Test Token ", vm.toString(i));
            string memory symbol = string.concat("TEST", vm.toString(i));
            tokens[i] = address(new ERC20Mock(name, symbol, 18));
            creditManager.setMask(tokens[i], 1 << i);
        }

        creditManager.setActiveCreditAccount(creditAccount);
    }

    modifier diffTestCases() {
        uint256 snapshot = vm.snapshot();

        diffLeftoverAmount = 501;
        diffInputAmount = 500;
        diffDisableTokenIn = false;
        _;

        vm.revertTo(snapshot);

        diffLeftoverAmount = 1;
        diffInputAmount = 1000;
        diffDisableTokenIn = true;
        _;
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

    function _executesCall(address[] memory tokensToApprove, address[] memory tokensToValidate, bytes memory callData)
        internal
    {
        for (uint256 i; i < tokensToValidate.length; ++i) {
            vm.expectCall(
                address(creditManager), abi.encodeCall(ICreditManagerV3.getTokenMaskOrRevert, (tokensToValidate[i]))
            );
        }

        for (uint256 i; i < tokensToApprove.length; ++i) {
            vm.expectCall(
                address(creditManager),
                abi.encodeCall(ICreditManagerV3.approveCreditAccount, (tokensToApprove[i], type(uint256).max))
            );

            vm.expectEmit(false, false, false, true, address(creditManager));
            emit Approve(tokensToApprove[i], type(uint256).max);
        }

        vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.execute, (callData)));
        vm.expectEmit(false, false, false, false, address(creditManager));
        emit Execute();

        for (uint256 i; i < tokensToApprove.length; ++i) {
            vm.expectCall(
                address(creditManager), abi.encodeCall(ICreditManagerV3.approveCreditAccount, (tokensToApprove[i], 1))
            );

            vm.expectEmit(false, false, false, true, address(creditManager));
            emit Approve(tokensToApprove[i], 1);
        }
    }
}
