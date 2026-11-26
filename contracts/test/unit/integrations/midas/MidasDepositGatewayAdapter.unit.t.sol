// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasDepositGatewayAdapter} from "../../../../integrations/midas/MidasDepositGatewayAdapter.sol";
import {IMidasDepositGatewayAdapter} from "../../../../integrations/midas/interfaces/IMidasDepositGatewayAdapter.sol";
import {IMidasDepositGateway} from "../../../../integrations/midas/interfaces/IMidasDepositGateway.sol";
import {IPhantomTokenAdapter} from "../../../../integrations/common/interfaces/IPhantomTokenAdapter.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @dev Minimal gateway mock - the adapter reads immutable token addresses from it.
contract MidasDepositGatewayMock {
    address public immutable mToken;
    address public immutable tokenIn;
    address public immutable phantomToken;

    constructor(address _mToken, address _tokenIn, address _phantomToken) {
        mToken = _mToken;
        tokenIn = _tokenIn;
        phantomToken = _phantomToken;
    }
}

/// @title Midas Deposit Gateway adapter unit test
/// @notice U:[MID-DA]: Unit tests for MidasDepositGatewayAdapter
contract MidasDepositGatewayAdapterUnitTest is AdapterUnitTestHelper {
    MidasDepositGatewayAdapter adapter;
    MidasDepositGatewayMock gateway;

    address mToken;
    address tokenIn;
    address phantomToken;

    function setUp() public {
        _setUp();

        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        creditManager.setMask(mToken, 1 << 9);

        tokenIn = tokens[0];

        phantomToken = makeAddr("PHANTOM_TOKEN");
        creditManager.setMask(phantomToken, 1 << 8);

        gateway = new MidasDepositGatewayMock(mToken, tokenIn, phantomToken);

        adapter = new MidasDepositGatewayAdapter(address(creditManager), address(gateway));
    }

    /// @notice U:[MID-DA-1]: Constructor works as expected
    function test_U_MID_DA_01_constructor_works_as_expected() public {
        _readsTokenMask(mToken);
        _readsTokenMask(tokenIn);
        _readsTokenMask(phantomToken);

        adapter = new MidasDepositGatewayAdapter(address(creditManager), address(gateway));

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(gateway), "Incorrect targetContract");
        assertEq(adapter.gateway(), address(gateway), "Incorrect gateway");
        assertEq(adapter.mToken(), mToken, "Incorrect mToken");
        assertEq(adapter.tokenIn(), tokenIn, "Incorrect tokenIn");
        assertEq(adapter.phantomToken(), phantomToken, "Incorrect phantomToken");
        assertEq(adapter.version(), 3_10, "Incorrect version");
        assertEq(adapter.contractType(), "ADAPTER::MIDAS_DEPOSIT_GATEWAY", "Incorrect contract type");
    }

    /// @notice U:[MID-DA-2]: `depositRequest` works as expected
    function test_U_MID_DA_02_depositRequest_works_as_expected() public {
        _executesSwap({
            tokenIn: tokenIn,
            callData: abi.encodeCall(IMidasDepositGateway.requestDeposit, (1000, "")),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        assertTrue(adapter.depositRequest(1000));
    }

    /// @notice U:[MID-DA-2A]: `depositRequest` with extraData works as expected
    function test_U_MID_DA_02A_depositRequest_with_extraData_works_as_expected() public {
        bytes memory extraData = abi.encode(uint256(42));
        _executesSwap({
            tokenIn: tokenIn,
            callData: abi.encodeCall(IMidasDepositGateway.requestDeposit, (1000, extraData)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        assertTrue(adapter.depositRequest(1000, extraData));
    }

    /// @notice U:[MID-DA-3]: `depositRequestHybrid` works as expected
    function test_U_MID_DA_03_depositRequestHybrid_works_as_expected() public {
        _executesSwap({
            tokenIn: tokenIn,
            callData: abi.encodeCall(IMidasDepositGateway.requestDepositHybrid, (1000, 2_500, 200, "")),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        assertTrue(adapter.depositRequestHybrid(1000, 2_500, 200));
    }

    /// @notice U:[MID-DA-4]: `withdraw` works as expected
    function test_U_MID_DA_04_withdraw_works_as_expected() public {
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMidasDepositGateway.withdraw, (1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        assertFalse(adapter.withdraw(1000));
    }

    /// @notice U:[MID-DA-5]: `withdrawFromDepositor` works as expected
    function test_U_MID_DA_05_withdrawFromDepositor_works_as_expected() public {
        address depositor = makeAddr("DEPOSITOR");
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMidasDepositGateway.withdrawFromDepositor, (depositor, 1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        assertFalse(adapter.withdrawFromDepositor(depositor, 1000));
    }

    /// @notice U:[MID-DA-6]: `transferDepositor` works as expected
    function test_U_MID_DA_06_transferDepositor_works_as_expected() public {
        address depositor = makeAddr("DEPOSITOR");
        address newAccount = makeAddr("NEW_ACCOUNT");
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMidasDepositGateway.transferDepositor, (depositor, newAccount)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        assertTrue(adapter.transferDepositor(depositor, newAccount));
    }

    /// @notice U:[MID-DA-7]: `withdrawPhantomToken` works as expected
    function test_U_MID_DA_07_withdrawPhantomToken_works_as_expected() public {
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMidasDepositGateway.withdraw, (1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        assertFalse(adapter.withdrawPhantomToken(phantomToken, 1000));
    }

    /// @notice U:[MID-DA-8]: `withdrawPhantomToken` reverts on wrong token
    function test_U_MID_DA_08_withdrawPhantomToken_reverts_on_wrong_token() public {
        vm.prank(creditFacade);
        vm.expectRevert(IPhantomTokenAdapter.IncorrectStakedPhantomTokenException.selector);
        adapter.withdrawPhantomToken(makeAddr("WRONG"), 1);
    }

    /// @notice U:[MID-DA-9]: `depositPhantomToken` always reverts
    function test_U_MID_DA_09_depositPhantomToken_reverts() public {
        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.depositPhantomToken(phantomToken, 1);
    }

    /// @notice U:[MID-DA-10]: Delayed methods revert when phantom token is unset
    function test_U_MID_DA_10_delayed_methods_revert_without_phantom_token() public {
        MidasDepositGatewayMock gatewayWithoutPhantom = new MidasDepositGatewayMock(mToken, tokenIn, address(0));
        MidasDepositGatewayAdapter adapterWithoutPhantom =
            new MidasDepositGatewayAdapter(address(creditManager), address(gatewayWithoutPhantom));

        vm.startPrank(creditFacade);

        vm.expectRevert(IMidasDepositGatewayAdapter.PhantomTokenNotSetException.selector);
        adapterWithoutPhantom.depositRequest(1);

        vm.expectRevert(IMidasDepositGatewayAdapter.PhantomTokenNotSetException.selector);
        adapterWithoutPhantom.withdraw(1);

        vm.stopPrank();
    }
}
