// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import "@gearbox-protocol/core-v3/contracts/interfaces/IAddressProviderV3.sol";
import {LidoV1Adapter, LIDO_STETH_LIMIT} from "../../../../adapters/lido/LidoV1.sol";
import {ILidoV1AdapterEvents, ILidoV1AdapterExceptions} from "../../../../interfaces/lido/ILidoV1Adapter.sol";
import {LidoV1Gateway} from "../../../../helpers/lido/LidoV1_WETHGateway.sol";
import {LidoMock, ILidoMockEvents} from "../../../mocks/integrations/LidoMock.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";

// TEST
import "../../../lib/constants.sol";

import {AdapterTestHelper} from "../AdapterTestHelper.sol";

// EXCEPTIONS

import "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

uint256 constant STETH_POOLED_ETH = 2 * WAD;
uint256 constant STETH_TOTAL_SHARES = WAD;

/// @title LidoV1AdapterTest
/// @notice Designed for unit test purposes only
contract LidoV1AdapterTest is
    Test,
    AdapterTestHelper,
    ILidoMockEvents,
    ILidoV1AdapterEvents,
    ILidoV1AdapterExceptions
{
    LidoMock public lidoV1Mock;
    LidoV1Gateway public lidoV1Gateway;
    LidoV1Adapter public lidoV1Adapter;

    address treasury;

    function setUp() public {
        _setUp(Tokens.WETH);

        lidoV1Mock = LidoMock(payable(tokenTestSuite.addressOf(Tokens.STETH)));

        lidoV1Gateway = new LidoV1Gateway(
            tokenTestSuite.addressOf(Tokens.WETH),
            address(lidoV1Mock)
        );

        lidoV1Adapter = new LidoV1Adapter(
            address(creditManager),
            address(lidoV1Gateway)
        );

        treasury = lidoV1Adapter.treasury();

        vm.prank(CONFIGURATOR);
        creditConfigurator.allowAdapter(address(lidoV1Adapter));

        treasury = addressProvider.getAddressOrRevert(AP_TREASURY, NO_VERSION_CONTROL);

        lidoV1Mock.syncExchangeRate(STETH_POOLED_ETH, STETH_TOTAL_SHARES);

        tokenTestSuite.approve(Tokens.WETH, USER, address(creditManager));

        vm.label(address(lidoV1Adapter), "ADAPTER_LIDO");
        vm.label(address(lidoV1Gateway), "GATEWAY_LIDO");
        vm.label(address(lidoV1Mock), "LIDO_MOCK");
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [LDOV1-1]: Constructor sets correct parameters
    function test_LDOV1_01_constructor_sets_correct_params() public {
        assertEq(lidoV1Adapter.stETH(), address(lidoV1Mock), "stETH address incorrect");
        assertEq(
            lidoV1Adapter.stETHTokenMask(),
            creditManager.getTokenMaskOrRevert(address(lidoV1Mock)),
            "stETH token mask incorrect"
        );

        assertEq(lidoV1Adapter.weth(), tokenTestSuite.addressOf(Tokens.WETH), "WETH address incorrect");
        assertEq(
            lidoV1Adapter.wethTokenMask(),
            creditManager.getTokenMaskOrRevert(tokenTestSuite.addressOf(Tokens.WETH)),
            "WETH token mask incorrect"
        );

        assertEq(
            lidoV1Adapter.treasury(),
            addressProvider.getAddressOrRevert(AP_TREASURY, NO_VERSION_CONTROL),
            "Treasury address incorrect"
        );
    }

    // /// @dev [LDOV1-2]: submit and submitAll reverts if user has no account
    // function test_LDOV1_02_submit_and_submitAll_reverts_if_user_has_no_account() public {
    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(creditAccount, address(lidoV1Adapter), abi.encodeCall(lidoV1Adapter.submit, (2 * WAD)));

    //     vm.expectRevert(ICreditManagerV3Exceptions.HasNoOpenedAccountException.selector);
    //     executeOneLineMulticall(creditAccount, address(lidoV1Adapter), abi.encodeCall(lidoV1Adapter.submitAll, ()));
    // }

    /// @dev [LDOV1-3]: Submit works correctly and fires events
    function test_LDOV1_03_submit_works_correctly() public {
        setUp();
        (address creditAccount, uint256 initialWETHamount) = _openTestCreditAccount();

        expectAllowance(Tokens.WETH, creditAccount, address(lidoV1Gateway), 0);

        bytes memory expectedCallData = abi.encodeCall(LidoV1Gateway.submit, (2 * WAD, DUMB_ADDRESS));

        expectMulticallStackCalls(
            address(lidoV1Adapter),
            address(lidoV1Gateway),
            USER,
            expectedCallData,
            tokenTestSuite.addressOf(Tokens.WETH),
            tokenTestSuite.addressOf(Tokens.STETH),
            true
        );

        executeOneLineMulticall(creditAccount, address(lidoV1Adapter), abi.encodeCall(LidoV1Adapter.submit, (2 * WAD)));

        expectBalance(Tokens.WETH, creditAccount, initialWETHamount - 2 * WAD);

        uint256 stETHExpectedSharesGateway = (2 * WAD * STETH_TOTAL_SHARES) / STETH_POOLED_ETH;
        uint256 stETHExpectedBalanceGateway = lidoV1Mock.getPooledEthByShares(stETHExpectedSharesGateway);

        uint256 stETHExpectedSharesAfterGatewayTransfer = lidoV1Mock.getSharesByPooledEth(stETHExpectedBalanceGateway);
        uint256 stETHExpectedBalance = lidoV1Mock.getPooledEthByShares(stETHExpectedSharesAfterGatewayTransfer);

        expectBalance(Tokens.STETH, creditAccount, stETHExpectedBalance);
        expectEthBalance(address(lidoV1Mock), 2 * WAD);
        expectAllowance(Tokens.WETH, creditAccount, address(lidoV1Gateway), 1);
        expectTokenIsEnabled(creditAccount, Tokens.STETH, true);
    }

    /// @dev [LDOV1-4]: submitAll works correctly and fires events
    function test_LDOV1_04_submitAll_works_correctly() public {
        setUp();

        (address creditAccount, uint256 initialWETHamount) = _openTestCreditAccount();

        expectAllowance(Tokens.WETH, creditAccount, address(lidoV1Gateway), 0);

        bytes memory expectedCallData = abi.encodeCall(LidoV1Gateway.submit, (initialWETHamount - 1, DUMB_ADDRESS));

        expectMulticallStackCalls(
            address(lidoV1Adapter),
            address(lidoV1Gateway),
            USER,
            expectedCallData,
            tokenTestSuite.addressOf(Tokens.WETH),
            tokenTestSuite.addressOf(Tokens.STETH),
            true
        );

        executeOneLineMulticall(creditAccount, address(lidoV1Adapter), abi.encodeCall(LidoV1Adapter.submitAll, ()));

        expectBalance(Tokens.WETH, creditAccount, 1);

        // Have to account for stETH precision errors

        uint256 stETHExpectedSharesGateway = ((initialWETHamount - 1) * STETH_TOTAL_SHARES) / STETH_POOLED_ETH;
        uint256 stETHExpectedBalanceGateway = lidoV1Mock.getPooledEthByShares(stETHExpectedSharesGateway);

        uint256 stETHExpectedSharesAfterGatewayTransfer = lidoV1Mock.getSharesByPooledEth(stETHExpectedBalanceGateway);
        uint256 stETHExpectedBalance = lidoV1Mock.getPooledEthByShares(stETHExpectedSharesAfterGatewayTransfer);

        expectBalance(Tokens.STETH, creditAccount, stETHExpectedBalance);
        expectEthBalance(address(lidoV1Mock), initialWETHamount - 1);
        expectAllowance(Tokens.WETH, creditAccount, address(lidoV1Gateway), 1);
        expectTokenIsEnabled(creditAccount, Tokens.WETH, false);
        expectTokenIsEnabled(creditAccount, Tokens.STETH, true);
    }
}
