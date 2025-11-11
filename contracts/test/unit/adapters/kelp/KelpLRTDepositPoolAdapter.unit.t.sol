// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KelpLRTDepositPoolAdapter} from "../../../../adapters/kelp/KelpLRTDepositPoolAdapter.sol";
import {KelpLRTDepositPoolGateway} from "../../../../helpers/kelp/KelpLRTDepositPoolGateway.sol";
import {IKelpLRTDepositPoolAdapter} from "../../../../interfaces/kelp/IKelpLRTDepositPoolAdapter.sol";
import {IKelpLRTDepositPoolGateway} from "../../../../interfaces/kelp/IKelpLRTDepositPoolGateway.sol";
import {IKelpLRTDepositPool} from "../../../../integrations/kelp/IKelpLRTDepositPool.sol";
import {IKelpLRTConfig} from "../../../../integrations/kelp/IKelpLRTConfig.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Kelp LRT deposit pool adapter unit test
/// @notice U:[KDP]: Unit tests for Kelp LRT deposit pool adapter
contract KelpLRTDepositPoolAdapterUnitTest is AdapterUnitTestHelper {
    KelpLRTDepositPoolAdapter adapter;

    address gateway;
    address depositPool;
    address lrtConfig;
    address rsETH;
    address weth;
    address stETH;
    address cbETH;

    function setUp() public {
        _setUp();

        weth = tokens[0];
        stETH = tokens[1];
        cbETH = tokens[2];
        rsETH = tokens[3];
        depositPool = makeAddr("DEPOSIT_POOL");
        lrtConfig = makeAddr("LRT_CONFIG");

        vm.mockCall(depositPool, abi.encodeCall(IKelpLRTDepositPool.lrtConfig, ()), abi.encode(lrtConfig));

        vm.mockCall(lrtConfig, abi.encodeCall(IKelpLRTConfig.rsETH, ()), abi.encode(rsETH));

        gateway = address(new KelpLRTDepositPoolGateway(weth, depositPool));

        adapter = new KelpLRTDepositPoolAdapter(address(creditManager), gateway);
    }

    /// @notice U:[KDP-1]: Constructor works as expected
    function test_U_KDP_01_constructor_works_as_expected() public {
        _readsTokenMask(rsETH);

        adapter = new KelpLRTDepositPoolAdapter(address(creditManager), gateway);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), gateway, "Incorrect targetContract");
    }

    /// @notice U:[KDP-2]: Wrapper functions revert on wrong caller
    function test_U_KDP_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.depositAsset(stETH, 1000, 900, "ref");

        _revertsOnNonFacadeCaller();
        adapter.depositAssetDiff(stETH, 100, 9e26, "ref");

        _revertsOnNonConfiguratorCaller();
        adapter.setAssetStatusBatch(new address[](0), new bool[](0));
    }

    /// @notice U:[KDP-3]: `depositAsset` works as expected
    function test_U_KDP_03_depositAsset_works_as_expected() public {
        vm.expectRevert(abi.encodeWithSelector(IKelpLRTDepositPoolAdapter.AssetNotAllowedException.selector, stETH));
        vm.prank(creditFacade);
        adapter.depositAsset(stETH, 1000, 900, "ref");

        _setAssetStatus(stETH, true);

        _executesSwap({
            tokenIn: stETH,
            callData: abi.encodeCall(IKelpLRTDepositPoolGateway.depositAsset, (stETH, 1000, 900, "ref")),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositAsset(stETH, 1000, 900, "ref");
        assertTrue(useSafePrices);
    }

    /// @notice U:[KDP-4]: `depositAssetDiff` works as expected
    function test_U_KDP_04_depositAssetDiff_works_as_expected() public diffTestCases {
        vm.expectRevert(abi.encodeWithSelector(IKelpLRTDepositPoolAdapter.AssetNotAllowedException.selector, stETH));
        vm.prank(creditFacade);
        adapter.depositAssetDiff(stETH, 100, 9e26, "ref");

        _setAssetStatus(stETH, true);

        deal({token: stETH, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: stETH,
            callData: abi.encodeCall(
                IKelpLRTDepositPoolGateway.depositAsset, (stETH, diffInputAmount, diffInputAmount * 9 / 10, "ref")
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositAssetDiff(stETH, diffLeftoverAmount, 9e26, "ref");
        assertTrue(useSafePrices);
    }

    /// @notice U:[KDP-5]: `depositAssetDiff` returns false when amount < leftoverAmount
    function test_U_KDP_05_depositAssetDiff_returns_false_when_nothing_to_deposit() public {
        _setAssetStatus(stETH, true);

        deal({token: stETH, to: creditAccount, give: 100});

        _readsActiveAccount();

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositAssetDiff(stETH, 101, 9e26, "ref");
        assertFalse(useSafePrices);
    }

    /// @notice U:[KDP-6]: `setAssetStatusBatch` works as expected
    function test_U_KDP_06_setAssetStatusBatch_works_as_expected() public {
        _revertsOnNonConfiguratorCaller();
        adapter.setAssetStatusBatch(new address[](0), new bool[](0));

        // Test with mismatched array lengths
        address[] memory assets = new address[](2);
        assets[0] = stETH;
        assets[1] = cbETH;

        bool[] memory statuses = new bool[](1);
        statuses[0] = true;

        vm.expectRevert(IKelpLRTDepositPoolAdapter.IncorrectArrayLengthException.selector);
        vm.prank(configurator);
        adapter.setAssetStatusBatch(assets, statuses);

        // Test with correct arrays
        statuses = new bool[](2);
        statuses[0] = true;
        statuses[1] = true;

        _readsTokenMask(stETH);
        _readsTokenMask(cbETH);

        vm.expectEmit(true, true, false, true);
        emit IKelpLRTDepositPoolAdapter.SetAssetStatus(stETH, true);

        vm.expectEmit(true, true, false, true);
        emit IKelpLRTDepositPoolAdapter.SetAssetStatus(cbETH, true);

        vm.prank(configurator);
        adapter.setAssetStatusBatch(assets, statuses);

        address[] memory allowedAssets = adapter.allowedAssets();
        assertEq(allowedAssets.length, 2, "Incorrect number of allowed assets");
        assertEq(allowedAssets[0], stETH, "Incorrect first allowed asset");
        assertEq(allowedAssets[1], cbETH, "Incorrect second allowed asset");

        // Test removing assets
        statuses[0] = false;

        vm.expectEmit(true, true, false, true);
        emit IKelpLRTDepositPoolAdapter.SetAssetStatus(stETH, false);

        vm.expectEmit(true, true, false, true);
        emit IKelpLRTDepositPoolAdapter.SetAssetStatus(cbETH, true);

        vm.prank(configurator);
        adapter.setAssetStatusBatch(assets, statuses);

        allowedAssets = adapter.allowedAssets();
        assertEq(allowedAssets.length, 1, "Incorrect number of allowed assets after removal");
        assertEq(allowedAssets[0], cbETH, "Incorrect remaining allowed asset");
    }

    /// @notice U:[KDP-7]: `serialize` works as expected
    function test_U_KDP_07_serialize_works_as_expected() public {
        _setAssetStatus(stETH, true);
        _setAssetStatus(cbETH, true);

        bytes memory serializedData = adapter.serialize();
        (address cm, address tc, address[] memory assets) = abi.decode(serializedData, (address, address, address[]));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, gateway, "Incorrect targetContract in serialized data");
        assertEq(assets.length, 2, "Incorrect number of assets in serialized data");
        assertEq(assets[0], stETH, "Incorrect first asset in serialized data");
        assertEq(assets[1], cbETH, "Incorrect second asset in serialized data");
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Sets status for an asset
    function _setAssetStatus(address asset, bool allowed) internal {
        address[] memory assets = new address[](1);
        assets[0] = asset;
        bool[] memory statuses = new bool[](1);
        statuses[0] = allowed;

        if (allowed) {
            _readsTokenMask(asset);
        }

        vm.prank(configurator);
        adapter.setAssetStatusBatch(assets, statuses);
    }
}
