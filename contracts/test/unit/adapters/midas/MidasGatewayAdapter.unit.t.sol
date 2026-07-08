// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasGatewayAdapter} from "../../../../adapters/midas/MidasGatewayAdapter.sol";
import {IMidasGatewayAdapter} from "../../../../interfaces/midas/IMidasGatewayAdapter.sol";
import {IMidasGateway} from "../../../../interfaces/midas/IMidasGateway.sol";
import {IPhantomTokenAdapter} from "../../../../interfaces/IPhantomTokenAdapter.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @dev Minimal gateway mock - the adapter only reads `mToken()` from it during construction,
///      all other interactions go through the credit manager's `execute`.
contract MidasGatewayMock {
    address public immutable mToken;

    constructor(address _mToken) {
        mToken = _mToken;
    }
}

/// @dev Mimics the `tokenOut()` getter that the adapter reads on phantom tokens during configuration.
contract MidasPhantomTokenMock {
    address public immutable tokenOut;

    constructor(address _tokenOut) {
        tokenOut = _tokenOut;
    }
}

/// @title Midas Gateway adapter unit test
/// @notice U:[MID-A]: Unit tests for MidasGatewayAdapter
contract MidasGatewayAdapterUnitTest is AdapterUnitTestHelper {
    MidasGatewayAdapter adapter;
    MidasGatewayMock gateway;

    address mToken;
    address inputToken0;
    address inputToken1;
    address outputToken0;
    address outputToken1;
    address phantomToken;

    bytes32 constant REFERRER_ID = bytes32(uint256(0xC0FFEE));

    function setUp() public {
        _setUp();

        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        creditManager.setMask(mToken, 1 << 9);

        inputToken0 = tokens[0];
        inputToken1 = tokens[1];
        outputToken0 = tokens[2];
        outputToken1 = tokens[3];

        phantomToken = address(new MidasPhantomTokenMock(outputToken0));
        creditManager.setMask(phantomToken, 1 << 8);

        gateway = new MidasGatewayMock(mToken);

        adapter = new MidasGatewayAdapter(address(creditManager), address(gateway), REFERRER_ID);

        _allowInputToken(inputToken0);
        _allowInputToken(inputToken1);
        _allowOutputToken(outputToken0, phantomToken);
        _allowOutputToken(outputToken1, address(0));
    }

    function _allowInputToken(address token) internal {
        address[] memory tks = new address[](1);
        tks[0] = token;
        bool[] memory allowed = new bool[](1);
        allowed[0] = true;
        vm.prank(configurator);
        adapter.setInputTokenAllowedStatusBatch(tks, allowed);
    }

    function _allowOutputToken(address token, address phantom) internal {
        IMidasGatewayAdapter.MidasAllowedTokenStatus[] memory configs =
            new IMidasGatewayAdapter.MidasAllowedTokenStatus[](1);
        configs[0] = IMidasGatewayAdapter.MidasAllowedTokenStatus({token: token, phantomToken: phantom, allowed: true});
        vm.prank(configurator);
        adapter.setOutputTokenAllowedStatusBatch(configs);
    }

    /// @notice U:[MID-A-1]: Constructor works as expected
    function test_U_MID_A_01_constructor_works_as_expected() public {
        _readsTokenMask(mToken);

        adapter = new MidasGatewayAdapter(address(creditManager), address(gateway), REFERRER_ID);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(gateway), "Incorrect targetContract");
        assertEq(adapter.gateway(), address(gateway), "Incorrect gateway");
        assertEq(adapter.mToken(), mToken, "Incorrect mToken");
        assertEq(adapter.referrerId(), REFERRER_ID, "Incorrect referrerId");
    }

    /// @notice U:[MID-A-2]: Wrapper functions revert on wrong caller
    function test_U_MID_A_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.depositInstant(inputToken0, 1000, 0, REFERRER_ID);

        _revertsOnNonFacadeCaller();
        adapter.depositInstantDiff(inputToken0, 1, 0);

        _revertsOnNonFacadeCaller();
        adapter.redeemInstant(outputToken0, 1000, 0);

        _revertsOnNonFacadeCaller();
        adapter.redeemInstantDiff(outputToken0, 1, 0);

        _revertsOnNonFacadeCaller();
        adapter.redeemRequest(outputToken0, 1000);

        _revertsOnNonFacadeCaller();
        adapter.withdraw(outputToken0, 1000);

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(phantomToken, 1000);

        _revertsOnNonFacadeCaller();
        adapter.depositPhantomToken(phantomToken, 1000);
    }

    /// @notice U:[MID-A-3]: Configuration functions revert on non-configurator caller
    function test_U_MID_A_03_configuration_functions_revert_on_wrong_caller() public {
        _revertsOnNonConfiguratorCaller();
        adapter.setInputTokenAllowedStatusBatch(new address[](0), new bool[](0));

        _revertsOnNonConfiguratorCaller();
        adapter.setOutputTokenAllowedStatusBatch(new IMidasGatewayAdapter.MidasAllowedTokenStatus[](0));
    }

    /// @notice U:[MID-A-4]: `depositInstant` works as expected
    function test_U_MID_A_04_depositInstant_works() public {
        _executesSwap({
            tokenIn: inputToken0,
            callData: abi.encodeCall(IMidasGateway.depositInstant, (inputToken0, 1000, 500, REFERRER_ID)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositInstant(inputToken0, 1000, 500, REFERRER_ID);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-5]: `depositInstant` reverts on disallowed token
    function test_U_MID_A_05_depositInstant_reverts_on_disallowed_token() public {
        vm.prank(creditFacade);
        vm.expectRevert(IMidasGatewayAdapter.TokenNotAllowedException.selector);
        adapter.depositInstant(outputToken0, 1000, 500, REFERRER_ID);
    }

    /// @notice U:[MID-A-6]: `depositInstantDiff` works as expected
    function test_U_MID_A_06_depositInstantDiff_works() public {
        deal(inputToken0, creditAccount, 1000);
        uint256 leftover = 100;
        uint256 amount = 900;
        uint256 minReceive = amount * RAY / RAY;

        _executesSwap({
            tokenIn: inputToken0,
            callData: abi.encodeCall(IMidasGateway.depositInstant, (inputToken0, amount, minReceive, REFERRER_ID)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositInstantDiff(inputToken0, leftover, RAY);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-7]: `depositInstantDiff` is a no-op when balance <= leftover
    function test_U_MID_A_07_depositInstantDiff_noop_when_nothing_to_deposit() public {
        deal(inputToken0, creditAccount, 100);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositInstantDiff(inputToken0, 100, RAY);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-8]: `redeemInstant` works as expected
    function test_U_MID_A_08_redeemInstant_works() public {
        _executesSwap({
            tokenIn: mToken,
            callData: abi.encodeCall(IMidasGateway.redeemInstant, (outputToken0, 1000, 500)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemInstant(outputToken0, 1000, 500);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-9]: `redeemInstant` reverts on disallowed token
    function test_U_MID_A_09_redeemInstant_reverts_on_disallowed_token() public {
        vm.prank(creditFacade);
        vm.expectRevert(IMidasGatewayAdapter.TokenNotAllowedException.selector);
        adapter.redeemInstant(inputToken0, 1000, 500);
    }

    /// @notice U:[MID-A-10]: `redeemInstantDiff` works as expected
    function test_U_MID_A_10_redeemInstantDiff_works() public {
        deal(mToken, creditAccount, 1000);
        uint256 leftover = 100;
        uint256 amount = 900;
        uint256 minReceive = amount * RAY / RAY;

        _executesSwap({
            tokenIn: mToken,
            callData: abi.encodeCall(IMidasGateway.redeemInstant, (outputToken0, amount, minReceive)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemInstantDiff(outputToken0, leftover, RAY);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-11]: `redeemInstantDiff` is a no-op when balance <= leftover
    function test_U_MID_A_11_redeemInstantDiff_noop_when_nothing_to_redeem() public {
        deal(mToken, creditAccount, 100);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemInstantDiff(outputToken0, 100, RAY);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-12]: `redeemRequest` works as expected
    function test_U_MID_A_12_redeemRequest_works() public {
        _executesSwap({
            tokenIn: mToken,
            callData: abi.encodeCall(IMidasGateway.requestRedeem, (outputToken0, 1000, "")),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemRequest(outputToken0, 1000);
        assertTrue(useSafePrices);
    }

    /// @notice U:[MID-A-13]: `redeemRequest` reverts when token is disallowed or has no phantom token
    function test_U_MID_A_13_redeemRequest_reverts() public {
        // disallowed token
        vm.prank(creditFacade);
        vm.expectRevert(IMidasGatewayAdapter.TokenNotAllowedException.selector);
        adapter.redeemRequest(inputToken0, 1000);

        // allowed token, but without an associated phantom token
        vm.prank(creditFacade);
        vm.expectRevert(IMidasGatewayAdapter.TokenNotAllowedException.selector);
        adapter.redeemRequest(outputToken1, 1000);
    }

    /// @notice U:[MID-A-14]: `withdraw` works as expected
    function test_U_MID_A_14_withdraw_works() public {
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMidasGateway.withdraw, (outputToken0, 1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdraw(outputToken0, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-A-15]: `withdrawPhantomToken` works as expected
    function test_U_MID_A_15_withdrawPhantomToken_works() public {
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMidasGateway.withdraw, (outputToken0, 1000)),
            requiresApproval: false
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

    /// @notice U:[MID-A-18]: `setInputTokenAllowedStatusBatch` works as expected
    function test_U_MID_A_18_setInputTokenAllowedStatusBatch_works() public {
        assertTrue(adapter.isInputTokenAllowed(inputToken0));
        assertTrue(adapter.isInputTokenAllowed(inputToken1));

        address[] memory allowedInputs = adapter.allowedInputTokens();
        assertEq(allowedInputs.length, 2, "Incorrect number of allowed input tokens");

        // remove one input token
        address[] memory tks = new address[](1);
        tks[0] = inputToken0;
        bool[] memory allowed = new bool[](1);
        allowed[0] = false;
        vm.prank(configurator);
        adapter.setInputTokenAllowedStatusBatch(tks, allowed);

        assertFalse(adapter.isInputTokenAllowed(inputToken0));
        assertEq(adapter.allowedInputTokens().length, 1, "Incorrect number of allowed input tokens after removal");
    }

    /// @notice U:[MID-A-19]: `setInputTokenAllowedStatusBatch` reverts on array length mismatch
    function test_U_MID_A_19_setInputTokenAllowedStatusBatch_reverts_on_length_mismatch() public {
        vm.prank(configurator);
        vm.expectRevert(IMidasGatewayAdapter.IncorrectArrayLengthException.selector);
        adapter.setInputTokenAllowedStatusBatch(new address[](2), new bool[](1));
    }

    /// @notice U:[MID-A-20]: `setInputTokenAllowedStatusBatch` reverts on unknown token
    function test_U_MID_A_20_setInputTokenAllowedStatusBatch_reverts_on_unknown_token() public {
        address[] memory tks = new address[](1);
        tks[0] = makeAddr("UNKNOWN_TOKEN");
        bool[] memory allowed = new bool[](1);
        allowed[0] = true;

        vm.prank(configurator);
        _revertsOnUnknownToken();
        adapter.setInputTokenAllowedStatusBatch(tks, allowed);
    }

    /// @notice U:[MID-A-21]: `setOutputTokenAllowedStatusBatch` works as expected
    function test_U_MID_A_21_setOutputTokenAllowedStatusBatch_works() public {
        assertTrue(adapter.isOutputTokenAllowed(outputToken0));
        assertTrue(adapter.isOutputTokenAllowed(outputToken1));

        assertEq(adapter.outputTokenToPhantomToken(outputToken0), phantomToken, "Incorrect phantom mapping");
        assertEq(adapter.phantomTokenToOutputToken(phantomToken), outputToken0, "Incorrect reverse phantom mapping");
        assertEq(adapter.outputTokenToPhantomToken(outputToken1), address(0), "Phantom set for instant-only token");

        address[] memory allowedOutputs = adapter.allowedOutputTokens();
        assertEq(allowedOutputs.length, 2, "Incorrect number of allowed output tokens");

        address[] memory phantomTokens = adapter.allowedPhantomTokens();
        assertEq(phantomTokens.length, 2, "Incorrect number of phantom tokens");

        // disabling the output token clears its phantom mappings
        _allowOutputToken(outputToken0, address(0));

        vm.prank(configurator);
        IMidasGatewayAdapter.MidasAllowedTokenStatus[] memory configs =
            new IMidasGatewayAdapter.MidasAllowedTokenStatus[](1);
        configs[0] = IMidasGatewayAdapter.MidasAllowedTokenStatus({
            token: outputToken0, phantomToken: address(0), allowed: false
        });
        adapter.setOutputTokenAllowedStatusBatch(configs);

        assertFalse(adapter.isOutputTokenAllowed(outputToken0));
        assertEq(adapter.outputTokenToPhantomToken(outputToken0), address(0), "Phantom mapping not cleared");
        assertEq(adapter.phantomTokenToOutputToken(phantomToken), address(0), "Reverse phantom mapping not cleared");
    }

    /// @notice U:[MID-A-22]: `setOutputTokenAllowedStatusBatch` reverts on phantom/output token mismatch
    function test_U_MID_A_22_setOutputTokenAllowedStatusBatch_reverts_on_phantom_mismatch() public {
        // phantom token tracks outputToken0, but we register it against outputToken1
        IMidasGatewayAdapter.MidasAllowedTokenStatus[] memory configs =
            new IMidasGatewayAdapter.MidasAllowedTokenStatus[](1);
        configs[0] = IMidasGatewayAdapter.MidasAllowedTokenStatus({
            token: outputToken1, phantomToken: phantomToken, allowed: true
        });

        vm.prank(configurator);
        vm.expectRevert(IMidasGatewayAdapter.PhantomTokenTokenOutMismatchException.selector);
        adapter.setOutputTokenAllowedStatusBatch(configs);
    }

    /// @notice U:[MID-A-23]: `setOutputTokenAllowedStatusBatch` reverts on unknown token
    function test_U_MID_A_23_setOutputTokenAllowedStatusBatch_reverts_on_unknown_token() public {
        IMidasGatewayAdapter.MidasAllowedTokenStatus[] memory configs =
            new IMidasGatewayAdapter.MidasAllowedTokenStatus[](1);
        configs[0] = IMidasGatewayAdapter.MidasAllowedTokenStatus({
            token: makeAddr("UNKNOWN_TOKEN"), phantomToken: address(0), allowed: true
        });

        vm.prank(configurator);
        _revertsOnUnknownToken();
        adapter.setOutputTokenAllowedStatusBatch(configs);
    }

    /// @notice U:[MID-A-24]: `serialize` works as expected
    function test_U_MID_A_24_serialize_works() public view {
        bytes memory serializedData = adapter.serialize();
        (
            address cm,
            address tc,
            address gw,
            address mtoken,
            bytes32 refId,
            address[] memory inputs,
            address[] memory outputs,
            address[] memory phantoms
        ) = abi.decode(serializedData, (address, address, address, address, bytes32, address[], address[], address[]));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, address(gateway), "Incorrect targetContract in serialized data");
        assertEq(gw, address(gateway), "Incorrect gateway in serialized data");
        assertEq(mtoken, mToken, "Incorrect mToken in serialized data");
        assertEq(refId, REFERRER_ID, "Incorrect referrerId in serialized data");
        assertEq(inputs.length, 2, "Incorrect number of input tokens in serialized data");
        assertEq(outputs.length, 2, "Incorrect number of output tokens in serialized data");
        assertEq(phantoms.length, 2, "Incorrect number of phantom tokens in serialized data");
    }
}
