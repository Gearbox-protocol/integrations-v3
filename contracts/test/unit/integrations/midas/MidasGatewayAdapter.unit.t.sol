// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
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

    bytes32 constant REFERRER_ID = bytes32(uint256(0xC0FFEE));

    function setUp() public {
        _setUp();

        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        creditManager.setMask(mToken, 1 << 9);

        quoteToken = tokens[0];

        phantomToken = makeAddr("PHANTOM_TOKEN");
        creditManager.setMask(phantomToken, 1 << 8);

        gateway = new MidasGatewayMock(mToken, quoteToken, phantomToken);

        adapter = new MidasGatewayAdapter(address(creditManager), address(gateway), REFERRER_ID);
    }

    /// @notice U:[MID-A-1]: Constructor works as expected
    function test_U_MID_A_01_constructor_works_as_expected() public {
        _readsTokenMask(mToken);

        _readsTokenMask(quoteToken);
        _readsTokenMask(phantomToken);

        adapter = new MidasGatewayAdapter(address(creditManager), address(gateway), REFERRER_ID);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(gateway), "Incorrect targetContract");
        assertEq(adapter.gateway(), address(gateway), "Incorrect gateway");
        assertEq(adapter.mToken(), mToken, "Incorrect mToken");
        assertEq(adapter.quoteToken(), quoteToken, "Incorrect quoteToken");
        assertEq(adapter.phantomToken(), phantomToken, "Incorrect phantomToken");
        assertEq(adapter.referrerId(), REFERRER_ID, "Incorrect referrerId");
    }

    /// @notice U:[MID-A-1A]: Constructor works when gateway has no phantom token
    function test_U_MID_A_01A_constructor_works_without_phantom_token() public {
        MidasGatewayMock gatewayWithoutPhantomToken = new MidasGatewayMock(mToken, quoteToken, address(0));

        _readsTokenMask(mToken);
        _readsTokenMask(quoteToken);

        MidasGatewayAdapter adapterWithoutPhantomToken =
            new MidasGatewayAdapter(address(creditManager), address(gatewayWithoutPhantomToken), REFERRER_ID);

        assertEq(adapterWithoutPhantomToken.phantomToken(), address(0), "Incorrect phantomToken");
    }

    /// @notice U:[MID-A-2]: Wrapper functions revert on wrong caller
    function test_U_MID_A_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.depositInstant(1000, 0, REFERRER_ID);

        _revertsOnNonFacadeCaller();
        adapter.depositInstantDiff(1, 0);

        _revertsOnNonFacadeCaller();
        adapter.redeemInstant(1000, 0);

        _revertsOnNonFacadeCaller();
        adapter.redeemInstantDiff(1, 0);

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
        adapter.withdrawPhantomToken(phantomToken, 1000);

        _revertsOnNonFacadeCaller();
        adapter.depositPhantomToken(phantomToken, 1000);
    }

    /// @notice U:[MID-A-4]: `depositInstant` works as expected
    function test_U_MID_A_04_depositInstant_works() public {
        _executesSwap({
            tokenIn: quoteToken,
            callData: abi.encodeCall(IMidasGateway.depositInstant, (1000, 500, REFERRER_ID)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositInstant(1000, 500, REFERRER_ID);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-6]: `depositInstantDiff` works as expected
    function test_U_MID_A_06_depositInstantDiff_works() public {
        deal(quoteToken, creditAccount, 1000);
        uint256 leftover = 100;
        uint256 amount = 900;
        uint256 minReceive = amount * RAY / RAY;

        _executesSwap({
            tokenIn: quoteToken,
            callData: abi.encodeCall(IMidasGateway.depositInstant, (amount, minReceive, REFERRER_ID)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositInstantDiff(leftover, RAY);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-7]: `depositInstantDiff` is a no-op when balance <= leftover
    function test_U_MID_A_07_depositInstantDiff_noop_when_nothing_to_deposit() public {
        deal(quoteToken, creditAccount, 100);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositInstantDiff(100, RAY);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-8]: `redeemInstant` works as expected
    function test_U_MID_A_08_redeemInstant_works() public {
        _executesSwap({
            tokenIn: mToken, callData: abi.encodeCall(IMidasGateway.redeemInstant, (1000, 500)), requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemInstant(1000, 500);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-10]: `redeemInstantDiff` works as expected
    function test_U_MID_A_10_redeemInstantDiff_works() public {
        deal(mToken, creditAccount, 1000);
        uint256 leftover = 100;
        uint256 amount = 900;
        uint256 minReceive = amount * RAY / RAY;

        _executesSwap({
            tokenIn: mToken,
            callData: abi.encodeCall(IMidasGateway.redeemInstant, (amount, minReceive)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemInstantDiff(leftover, RAY);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-11]: `redeemInstantDiff` is a no-op when balance <= leftover
    function test_U_MID_A_11_redeemInstantDiff_noop_when_nothing_to_redeem() public {
        deal(mToken, creditAccount, 100);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemInstantDiff(100, RAY);
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

    /// @notice U:[MID-A-12E]: `redeemRequest` reverts when phantom token is not set
    function test_U_MID_A_12E_redeemRequest_reverts_without_phantom_token() public {
        MidasGatewayMock gatewayWithoutPhantomToken = new MidasGatewayMock(mToken, quoteToken, address(0));
        MidasGatewayAdapter adapterWithoutPhantomToken =
            new MidasGatewayAdapter(address(creditManager), address(gatewayWithoutPhantomToken), REFERRER_ID);

        vm.expectRevert(IMidasGatewayAdapter.PhantomTokenNotSetException.selector);
        vm.prank(creditFacade);
        adapterWithoutPhantomToken.redeemRequest(1000);
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
        (address cm, address tc, address gw, address mtoken, address qtoken, address phantom, bytes32 refId) =
            abi.decode(serializedData, (address, address, address, address, address, address, bytes32));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, address(gateway), "Incorrect targetContract in serialized data");
        assertEq(gw, address(gateway), "Incorrect gateway in serialized data");
        assertEq(mtoken, mToken, "Incorrect mToken in serialized data");
        assertEq(qtoken, quoteToken, "Incorrect quoteToken in serialized data");
        assertEq(phantom, phantomToken, "Incorrect phantomToken in serialized data");
        assertEq(refId, REFERRER_ID, "Incorrect referrerId in serialized data");
    }
}
