// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {TokenNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AaveHorizonBridgeAdapter} from "../../../../integrations/aave/AaveHorizonBridgeAdapter.sol";
import {IAaveHorizonBridge} from "../../../../integrations/aave/interfaces/IAaveHorizonBridge.sol";
import {
    AaveHorizonTokenStatus,
    IAaveHorizonBridgeAdapter
} from "../../../../integrations/aave/interfaces/IAaveHorizonBridgeAdapter.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Aave Horizon Bridge adapter unit test
/// @notice U:[AHBA]: Unit tests for AaveHorizonBridgeAdapter
contract AaveHorizonBridgeAdapterUnitTest is AdapterUnitTestHelper {
    AaveHorizonBridgeAdapter adapter;

    address aToken;
    address debtToken;
    address bridge;

    function setUp() public {
        _setUp();

        aToken = tokens[0];
        debtToken = tokens[1];
        bridge = makeAddr("AAVE_HORIZON_BRIDGE");

        adapter = new AaveHorizonBridgeAdapter(address(creditManager), bridge);

        _allowTokens(aToken, debtToken);
    }

    function _allowTokens(address aToken_, address debtToken_) internal {
        AaveHorizonTokenStatus[] memory aTokens = new AaveHorizonTokenStatus[](1);
        aTokens[0] = AaveHorizonTokenStatus({token: aToken_, allowed: true});
        AaveHorizonTokenStatus[] memory debtTokens = new AaveHorizonTokenStatus[](1);
        debtTokens[0] = AaveHorizonTokenStatus({token: debtToken_, allowed: true});

        vm.startPrank(configurator);
        adapter.setATokenStatusBatch(aTokens);
        adapter.setDebtTokenStatusBatch(debtTokens);
        vm.stopPrank();
    }

    /// @notice U:[AHBA-1]: Constructor works as expected
    function test_U_AHBA_01_constructor_works_as_expected() public view {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), bridge, "Incorrect targetContract");
        assertEq(adapter.bridge(), bridge, "Incorrect bridge");
        assertEq(adapter.contractType(), "ADAPTER::AAVE_HORIZON_BRIDGE", "Incorrect contractType");
        assertEq(adapter.version(), 3_11, "Incorrect version");
    }

    /// @notice U:[AHBA-2]: Wrapper functions revert on wrong caller
    function test_U_AHBA_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.openPosition(aToken, debtToken, 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.openPositionDiff(aToken, debtToken, 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.closePosition(aToken, debtToken, 0, 0);
    }

    /// @notice U:[AHBA-3]: `openPosition` works as expected
    function test_U_AHBA_03_openPosition_works_as_expected() public {
        _executesSwap({
            tokenIn: aToken,
            callData: abi.encodeCall(IAaveHorizonBridge.openPosition, (aToken, debtToken, 1000, 500)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.openPosition(aToken, debtToken, 1000, 500);
        assertFalse(useSafePrices);
    }

    /// @notice U:[AHBA-3A]: `openPositionDiff` works as expected
    function test_U_AHBA_03A_openPositionDiff_works_as_expected() public diffTestCases {
        deal({token: aToken, to: creditAccount, give: diffMintedAmount});

        _executesSwap({
            tokenIn: aToken,
            callData: abi.encodeCall(IAaveHorizonBridge.openPosition, (aToken, debtToken, diffInputAmount, 500)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.openPositionDiff(aToken, debtToken, diffLeftoverAmount, 500);
        assertFalse(useSafePrices);
    }

    /// @notice U:[AHBA-4]: `closePosition` works as expected
    function test_U_AHBA_04_closePosition_works_as_expected() public {
        _executesSwap({
            tokenIn: debtToken,
            callData: abi.encodeCall(IAaveHorizonBridge.closePosition, (aToken, debtToken, 500, 1000)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.closePosition(aToken, debtToken, 500, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[AHBA-5]: open/close revert when tokens are not allowlisted
    function test_U_AHBA_05_reverts_when_token_not_allowed() public {
        address unknownAToken = tokens[2];
        address unknownDebtToken = tokens[3];

        vm.prank(creditFacade);
        vm.expectRevert(TokenNotAllowedException.selector);
        adapter.openPosition(unknownAToken, debtToken, 1000, 500);

        vm.prank(creditFacade);
        vm.expectRevert(TokenNotAllowedException.selector);
        adapter.openPosition(aToken, unknownDebtToken, 1000, 500);

        vm.prank(creditFacade);
        vm.expectRevert(TokenNotAllowedException.selector);
        adapter.closePosition(unknownAToken, debtToken, 500, 1000);

        vm.prank(creditFacade);
        vm.expectRevert(TokenNotAllowedException.selector);
        adapter.closePosition(aToken, unknownDebtToken, 500, 1000);
    }

    /// @notice U:[AHBA-6]: `setATokenStatusBatch` / `setDebtTokenStatusBatch` work as expected
    function test_U_AHBA_06_token_status_batch_works_as_expected() public {
        AaveHorizonTokenStatus[] memory aTokens = new AaveHorizonTokenStatus[](2);
        aTokens[0] = AaveHorizonTokenStatus({token: aToken, allowed: false});
        aTokens[1] = AaveHorizonTokenStatus({token: tokens[2], allowed: true});

        _revertsOnNonConfiguratorCaller();
        adapter.setATokenStatusBatch(aTokens);

        _readsTokenMask(tokens[2]);
        vm.expectEmit(true, false, false, true);
        emit IAaveHorizonBridgeAdapter.SetATokenStatus(aToken, false);
        vm.expectEmit(true, false, false, true);
        emit IAaveHorizonBridgeAdapter.SetATokenStatus(tokens[2], true);

        vm.prank(configurator);
        adapter.setATokenStatusBatch(aTokens);

        assertFalse(adapter.isATokenAllowed(aToken), "aToken should be disallowed");
        assertTrue(adapter.isATokenAllowed(tokens[2]), "tokens[2] should be allowed");

        address[] memory allowedA = adapter.allowedATokens();
        assertEq(allowedA.length, 1, "Incorrect aToken allowlist length");
        assertEq(allowedA[0], tokens[2], "Incorrect allowed aToken");

        AaveHorizonTokenStatus[] memory debtTokens = new AaveHorizonTokenStatus[](2);
        debtTokens[0] = AaveHorizonTokenStatus({token: debtToken, allowed: false});
        debtTokens[1] = AaveHorizonTokenStatus({token: tokens[3], allowed: true});

        _revertsOnNonConfiguratorCaller();
        adapter.setDebtTokenStatusBatch(debtTokens);

        _readsTokenMask(tokens[3]);
        vm.expectEmit(true, false, false, true);
        emit IAaveHorizonBridgeAdapter.SetDebtTokenStatus(debtToken, false);
        vm.expectEmit(true, false, false, true);
        emit IAaveHorizonBridgeAdapter.SetDebtTokenStatus(tokens[3], true);

        vm.prank(configurator);
        adapter.setDebtTokenStatusBatch(debtTokens);

        assertFalse(adapter.isDebtTokenAllowed(debtToken), "debtToken should be disallowed");
        assertTrue(adapter.isDebtTokenAllowed(tokens[3]), "tokens[3] should be allowed");

        address[] memory allowedD = adapter.allowedDebtTokens();
        assertEq(allowedD.length, 1, "Incorrect debt token allowlist length");
        assertEq(allowedD[0], tokens[3], "Incorrect allowed debt token");
    }

    /// @notice U:[AHBA-7]: `serialize` works as expected
    function test_U_AHBA_07_serialize_works_as_expected() public view {
        (address cm, address tc, address bridge_, address[] memory aTokens, address[] memory debtTokens) =
            abi.decode(adapter.serialize(), (address, address, address, address[], address[]));

        assertEq(cm, address(creditManager), "Incorrect creditManager");
        assertEq(tc, bridge, "Incorrect targetContract");
        assertEq(bridge_, bridge, "Incorrect bridge");
        assertEq(aTokens.length, 1, "Incorrect aTokens length");
        assertEq(aTokens[0], aToken, "Incorrect aToken");
        assertEq(debtTokens.length, 1, "Incorrect debtTokens length");
        assertEq(debtTokens[0], debtToken, "Incorrect debtToken");
    }
}
