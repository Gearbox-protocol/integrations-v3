// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {TreehouseRouterAdapter} from "../../../../integrations/treehouse/TreehouseRouterAdapter.sol";
import {ITreehouseRouter} from "../../../../integrations/treehouse/interfaces/external/ITreehouseRouter.sol";
import {ITreehouseRouterAdapter} from "../../../../integrations/treehouse/interfaces/ITreehouseRouterAdapter.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @dev Minimal router mock — the adapter reads TASSET from it in the constructor.
contract TreehouseRouterMock {
    address public immutable TASSET;

    constructor(address tAsset_) {
        TASSET = tAsset_;
    }
}

/// @title Treehouse Router adapter unit test
/// @notice U:[TH-R]: Unit tests for TreehouseRouterAdapter
contract TreehouseRouterAdapterUnitTest is AdapterUnitTestHelper {
    TreehouseRouterAdapter adapter;
    TreehouseRouterMock router;

    address tAsset;
    address asset0;
    address asset1;

    function setUp() public {
        _setUp();

        tAsset = tokens[0];
        asset0 = tokens[1];
        asset1 = tokens[2];

        router = new TreehouseRouterMock(tAsset);
        adapter = new TreehouseRouterAdapter(address(creditManager), address(router));

        _allowAsset(asset0);
    }

    function _allowAsset(address asset) internal {
        address[] memory assets = new address[](1);
        bool[] memory allowed = new bool[](1);
        assets[0] = asset;
        allowed[0] = true;
        vm.prank(configurator);
        adapter.setAssetStatusBatch(assets, allowed);
    }

    /// @notice U:[TH-R-1]: Constructor works as expected
    function test_U_TH_R_01_constructor_works_as_expected() public {
        _readsTokenMask(tAsset);

        adapter = new TreehouseRouterAdapter(address(creditManager), address(router));

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(router), "Incorrect targetContract");
        assertEq(adapter.contractType(), "ADAPTER::TREEHOUSE_ROUTER", "Incorrect contractType");
        assertEq(adapter.version(), 3_10, "Incorrect version");
        assertEq(adapter.allowedAssets().length, 0, "Should start with no allowed assets");
    }

    /// @notice U:[TH-R-2]: Wrapper functions revert on wrong caller
    function test_U_TH_R_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.deposit(asset0, 1000);

        _revertsOnNonFacadeCaller();
        adapter.depositDiff(asset0, 100);
    }

    /// @notice U:[TH-R-3]: `deposit` reverts for disallowed asset
    function test_U_TH_R_03_deposit_reverts_for_disallowed_asset() public {
        vm.expectRevert(ITreehouseRouterAdapter.InvalidAssetException.selector);
        vm.prank(creditFacade);
        adapter.deposit(asset1, 1000);
    }

    /// @notice U:[TH-R-4]: `deposit` works as expected
    function test_U_TH_R_04_deposit_works_as_expected() public {
        _executesSwap({
            tokenIn: asset0, callData: abi.encodeCall(ITreehouseRouter.deposit, (asset0, 1000)), requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.deposit(asset0, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[TH-R-5]: `depositDiff` reverts for disallowed asset
    function test_U_TH_R_05_depositDiff_reverts_for_disallowed_asset() public {
        deal(asset1, creditAccount, 1000);

        vm.expectRevert(ITreehouseRouterAdapter.InvalidAssetException.selector);
        vm.prank(creditFacade);
        adapter.depositDiff(asset1, 100);
    }

    /// @notice U:[TH-R-6]: `depositDiff` is a no-op when balance <= leftover
    function test_U_TH_R_06_depositDiff_noop_when_nothing_to_deposit() public {
        deal(asset0, creditAccount, 100);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositDiff(asset0, 100);
        assertFalse(useSafePrices);
    }

    /// @notice U:[TH-R-7]: `depositDiff` works as expected
    function test_U_TH_R_07_depositDiff_works_as_expected() public diffTestCases {
        deal({token: asset0, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: asset0,
            callData: abi.encodeCall(ITreehouseRouter.deposit, (asset0, diffInputAmount)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositDiff(asset0, diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[TH-R-8]: `setAssetStatusBatch` works as expected
    function test_U_TH_R_08_setAssetStatusBatch_works_as_expected() public {
        address[] memory assets = new address[](2);
        bool[] memory allowed = new bool[](2);
        assets[0] = asset0;
        assets[1] = asset1;
        allowed[0] = false;
        allowed[1] = true;

        _revertsOnNonConfiguratorCaller();
        adapter.setAssetStatusBatch(assets, allowed);

        _readsTokenMask(asset1);

        vm.expectEmit(true, false, false, true);
        emit ITreehouseRouterAdapter.SetAssetStatus(asset0, false);
        vm.expectEmit(true, false, false, true);
        emit ITreehouseRouterAdapter.SetAssetStatus(asset1, true);

        vm.prank(configurator);
        adapter.setAssetStatusBatch(assets, allowed);

        assertFalse(adapter.isAssetAllowed(asset0), "First asset incorrectly allowed");
        assertTrue(adapter.isAssetAllowed(asset1), "Second asset incorrectly not allowed");

        address[] memory allowedList = adapter.allowedAssets();
        assertEq(allowedList.length, 1, "Incorrect allowed assets length");
        assertEq(allowedList[0], asset1, "Incorrect allowed asset");
    }

    /// @notice U:[TH-R-9]: `setAssetStatusBatch` reverts for unknown token when allowing
    function test_U_TH_R_09_setAssetStatusBatch_reverts_for_unknown_token() public {
        address unknown = makeAddr("UNKNOWN_TOKEN");

        address[] memory assets = new address[](1);
        bool[] memory allowed = new bool[](1);
        assets[0] = unknown;
        allowed[0] = true;

        _revertsOnUnknownToken();
        vm.prank(configurator);
        adapter.setAssetStatusBatch(assets, allowed);
    }

    /// @notice U:[TH-R-10]: `serialize` works as expected
    function test_U_TH_R_10_serialize_works_as_expected() public view {
        bytes memory serializedData = adapter.serialize();
        (address cm, address tc, address[] memory allowed) = abi.decode(serializedData, (address, address, address[]));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, address(router), "Incorrect targetContract in serialized data");
        assertEq(allowed.length, 1, "Incorrect allowed assets length");
        assertEq(allowed[0], asset0, "Incorrect allowed asset");
    }
}
