// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasGatewayAdapter} from "../../../../integrations/midas/MidasGatewayAdapter.sol";
import {IMidasGatewayAdapter} from "../../../../integrations/midas/interfaces/IMidasGatewayAdapter.sol";
import {IMidasGateway} from "../../../../integrations/midas/interfaces/IMidasGateway.sol";
import {IPhantomTokenAdapter} from "../../../../integrations/common/interfaces/IPhantomTokenAdapter.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @dev Minimal gateway mock - the adapter reads immutable token addresses from it.
contract MidasGatewayMock {
    address public immutable mToken;
    address public immutable quoteToken;
    address public immutable phantomToken;

    constructor(address _mToken, address _quoteToken, address _phantomToken) {
        mToken = _mToken;
        quoteToken = _quoteToken;
        phantomToken = _phantomToken;
    }
}

/// @title Midas Gateway adapter unit test
/// @notice U:[MID-A]: Unit tests for MidasGatewayAdapter
contract MidasGatewayAdapterUnitTest is AdapterUnitTestHelper {
    MidasGatewayAdapter adapter;
    MidasGatewayMock gateway;

    address mToken;
    address quoteToken;
    address phantomToken;

    function setUp() public {
        _setUp();

        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        creditManager.setMask(mToken, 1 << 9);

        quoteToken = tokens[0];

        phantomToken = makeAddr("PHANTOM_TOKEN");
        creditManager.setMask(phantomToken, 1 << 8);

        gateway = new MidasGatewayMock(mToken, quoteToken, phantomToken);

        adapter = new MidasGatewayAdapter(address(creditManager), address(gateway));
    }

    /// @notice U:[MID-A-1]: Constructor works as expected
    function test_U_MID_A_01_constructor_works_as_expected() public {
        _readsTokenMask(mToken);

        _readsTokenMask(quoteToken);
        _readsTokenMask(phantomToken);

        adapter = new MidasGatewayAdapter(address(creditManager), address(gateway));

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(gateway), "Incorrect targetContract");
        assertEq(adapter.gateway(), address(gateway), "Incorrect gateway");
        assertEq(adapter.mToken(), mToken, "Incorrect mToken");
        assertEq(adapter.quoteToken(), quoteToken, "Incorrect quoteToken");
        assertEq(adapter.phantomToken(), phantomToken, "Incorrect phantomToken");
    }

    /// @notice U:[MID-A-1A]: Constructor works when gateway has no phantom token
    function test_U_MID_A_01A_constructor_works_without_phantom_token() public {
        MidasGatewayMock gatewayWithoutPhantomToken = new MidasGatewayMock(mToken, quoteToken, address(0));

        _readsTokenMask(mToken);
        _readsTokenMask(quoteToken);

        MidasGatewayAdapter adapterWithoutPhantomToken =
            new MidasGatewayAdapter(address(creditManager), address(gatewayWithoutPhantomToken));

        assertEq(adapterWithoutPhantomToken.phantomToken(), address(0), "Incorrect phantomToken");
    }

    /// @notice U:[MID-A-2]: Wrapper functions revert on wrong caller
    function test_U_MID_A_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.receiveGreenlist();

        _revertsOnNonFacadeCaller();
        adapter.redeemRequest(1000);

        _revertsOnNonFacadeCaller();
        adapter.redeemRequest(1000, "");

        _revertsOnNonFacadeCaller();
        adapter.redeemRequestDiff(1);

        _revertsOnNonFacadeCaller();
        adapter.redeemRequestDiff(1, "");

        _revertsOnNonFacadeCaller();
        adapter.withdraw(1000);

        _revertsOnNonFacadeCaller();
        adapter.withdrawFromRedeemer(makeAddr("REDEEMER"), 1000);

        _revertsOnNonFacadeCaller();
        adapter.transferRedeemer(makeAddr("REDEEMER"), makeAddr("NEW_ACCOUNT"));

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(phantomToken, 1000);

        _revertsOnNonFacadeCaller();
        adapter.depositPhantomToken(phantomToken, 1000);
    }

    /// @notice U:[MID-A-3]: `receiveGreenlist` works as expected
    function test_U_MID_A_03_receiveGreenlist_works() public {
        _executesSwap({
            tokenIn: address(0), callData: abi.encodeCall(IMidasGateway.receiveGreenlist, ()), requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.receiveGreenlist();
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-3A]: `receiveGreenlist` works when phantom token is not set
    function test_U_MID_A_03A_receiveGreenlist_works_without_phantom_token() public {
        MidasGatewayMock gatewayWithoutPhantomToken = new MidasGatewayMock(mToken, quoteToken, address(0));
        MidasGatewayAdapter adapterWithoutPhantomToken =
            new MidasGatewayAdapter(address(creditManager), address(gatewayWithoutPhantomToken));

        _executesSwap({
            tokenIn: address(0), callData: abi.encodeCall(IMidasGateway.receiveGreenlist, ()), requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapterWithoutPhantomToken.receiveGreenlist();
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-12]: `redeemRequest` works as expected
    function test_U_MID_A_12_redeemRequest_works() public {
        _executesSwap({
            tokenIn: mToken, callData: abi.encodeCall(IMidasGateway.requestRedeem, (1000, "")), requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemRequest(1000);
        assertTrue(useSafePrices);
    }

    /// @notice U:[MID-A-12A]: `redeemRequest` with extraData works as expected
    function test_U_MID_A_12A_redeemRequest_with_extraData_works() public {
        bytes memory extraData = abi.encode(uint256(42));

        _executesSwap({
            tokenIn: mToken,
            callData: abi.encodeCall(IMidasGateway.requestRedeem, (1000, extraData)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemRequest(1000, extraData);
        assertTrue(useSafePrices);
    }

    /// @notice U:[MID-A-12B]: `redeemRequestDiff` works as expected
    function test_U_MID_A_12B_redeemRequestDiff_works() public {
        deal(mToken, creditAccount, 1000);
        uint256 leftover = 100;
        uint256 amount = 900;

        _executesSwap({
            tokenIn: mToken, callData: abi.encodeCall(IMidasGateway.requestRedeem, (amount, "")), requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemRequestDiff(leftover);
        assertTrue(useSafePrices);
    }

    /// @notice U:[MID-A-12C]: `redeemRequestDiff` with extraData works as expected
    function test_U_MID_A_12C_redeemRequestDiff_with_extraData_works() public {
        deal(mToken, creditAccount, 1000);
        uint256 leftover = 100;
        uint256 amount = 900;
        bytes memory extraData = abi.encode(uint256(42));

        _executesSwap({
            tokenIn: mToken,
            callData: abi.encodeCall(IMidasGateway.requestRedeem, (amount, extraData)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemRequestDiff(leftover, extraData);
        assertTrue(useSafePrices);
    }

    /// @notice U:[MID-A-12D]: `redeemRequestDiff` is a no-op when balance <= leftover
    function test_U_MID_A_12D_redeemRequestDiff_noop_when_nothing_to_redeem() public {
        deal(mToken, creditAccount, 100);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemRequestDiff(100);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-12E]: Delayed-redemption functions revert when phantom token is not set
    function test_U_MID_A_12E_execution_reverts_without_phantom_token() public {
        MidasGatewayMock gatewayWithoutPhantomToken = new MidasGatewayMock(mToken, quoteToken, address(0));
        MidasGatewayAdapter adapterWithoutPhantomToken =
            new MidasGatewayAdapter(address(creditManager), address(gatewayWithoutPhantomToken));

        vm.startPrank(creditFacade);

        vm.expectRevert(IMidasGatewayAdapter.PhantomTokenNotSetException.selector);
        adapterWithoutPhantomToken.redeemRequest(1000);

        vm.expectRevert(IMidasGatewayAdapter.PhantomTokenNotSetException.selector);
        adapterWithoutPhantomToken.withdraw(1000);

        vm.expectRevert(IMidasGatewayAdapter.PhantomTokenNotSetException.selector);
        adapterWithoutPhantomToken.withdrawFromRedeemer(makeAddr("REDEEMER"), 1000);

        vm.expectRevert(IMidasGatewayAdapter.PhantomTokenNotSetException.selector);
        adapterWithoutPhantomToken.transferRedeemer(makeAddr("REDEEMER"), makeAddr("NEW_ACCOUNT"));

        vm.expectRevert(IMidasGatewayAdapter.PhantomTokenNotSetException.selector);
        adapterWithoutPhantomToken.withdrawPhantomToken(address(0), 1000);

        vm.expectRevert(IMidasGatewayAdapter.PhantomTokenNotSetException.selector);
        adapterWithoutPhantomToken.depositPhantomToken(address(0), 1000);

        vm.stopPrank();
    }

    /// @notice U:[MID-A-14]: `withdraw` works as expected
    function test_U_MID_A_14_withdraw_works() public {
        _executesSwap({
            tokenIn: address(0), callData: abi.encodeCall(IMidasGateway.withdraw, (1000)), requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdraw(1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-14A]: `withdrawFromRedeemer` works as expected
    function test_U_MID_A_14A_withdrawFromRedeemer_works() public {
        address redeemer = makeAddr("REDEEMER");

        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMidasGateway.withdrawFromRedeemer, (redeemer, 1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawFromRedeemer(redeemer, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-14B]: `transferRedeemer` works as expected
    function test_U_MID_A_14B_transferRedeemer_works() public {
        address redeemer = makeAddr("REDEEMER");
        address newAccount = makeAddr("NEW_ACCOUNT");

        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMidasGateway.transferRedeemer, (redeemer, newAccount)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.transferRedeemer(redeemer, newAccount);
        assertTrue(useSafePrices);
    }

    /// @notice U:[MID-A-15]: `withdrawPhantomToken` works as expected
    function test_U_MID_A_15_withdrawPhantomToken_works() public {
        _executesSwap({
            tokenIn: address(0), callData: abi.encodeCall(IMidasGateway.withdraw, (1000)), requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawPhantomToken(phantomToken, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-16]: `withdrawPhantomToken` reverts on unknown phantom token
    function test_U_MID_A_16_withdrawPhantomToken_reverts_on_unknown_phantom() public {
        vm.prank(creditFacade);
        vm.expectRevert(IPhantomTokenAdapter.IncorrectStakedPhantomTokenException.selector);
        adapter.withdrawPhantomToken(makeAddr("UNKNOWN_PHANTOM"), 1000);
    }

    /// @notice U:[MID-A-17]: `depositPhantomToken` reverts as not implemented
    function test_U_MID_A_17_depositPhantomToken_reverts() public {
        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.depositPhantomToken(phantomToken, 1000);
    }

    /// @notice U:[MID-A-19]: `serialize` works as expected
    function test_U_MID_A_19_serialize_works() public view {
        bytes memory serializedData = adapter.serialize();
        (address cm, address tc, address gw, address mtoken, address qtoken, address phantom) =
            abi.decode(serializedData, (address, address, address, address, address, address));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, address(gateway), "Incorrect targetContract in serialized data");
        assertEq(gw, address(gateway), "Incorrect gateway in serialized data");
        assertEq(mtoken, mToken, "Incorrect mToken in serialized data");
        assertEq(qtoken, quoteToken, "Incorrect quoteToken in serialized data");
        assertEq(phantom, phantomToken, "Incorrect phantomToken in serialized data");
    }
}
