// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {TokenNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AaveV3PoolAdapter} from "../../../../integrations/aave/AaveV3PoolAdapter.sol";
import {IAaveV3Pool} from "../../../../integrations/aave/interfaces/external/IAaveV3Pool.sol";
import {AaveV3AssetStatus, IAaveV3PoolAdapter} from "../../../../integrations/aave/interfaces/IAaveV3PoolAdapter.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Aave V3 Pool adapter unit test
/// @notice U:[A3P]: Unit tests for AaveV3PoolAdapter
contract AaveV3PoolAdapterUnitTest is AdapterUnitTestHelper {
    AaveV3PoolAdapter adapter;

    address asset;
    address aToken;
    address aavePool;

    uint16 constant REFERRAL_CODE = 7;

    function setUp() public {
        _setUp();

        asset = tokens[0];
        aToken = tokens[1];
        aavePool = makeAddr("AAVE_POOL");

        vm.mockCall(aavePool, abi.encodeCall(IAaveV3Pool.getReserveAToken, (asset)), abi.encode(aToken));

        adapter = new AaveV3PoolAdapter(address(creditManager), aavePool, REFERRAL_CODE);
        _allowAsset(asset);
    }

    function _allowAsset(address asset_) internal {
        AaveV3AssetStatus[] memory assets = new AaveV3AssetStatus[](1);
        assets[0] = AaveV3AssetStatus({asset: asset_, allowed: true});
        vm.prank(configurator);
        adapter.setAssetStatusBatch(assets);
    }

    /// @notice U:[A3P-1]: Constructor works as expected
    function test_U_A3P_01_constructor_works_as_expected() public view {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), aavePool, "Incorrect targetContract");
        assertEq(adapter.pool(), aavePool, "Incorrect pool");
        assertEq(adapter.referralCode(), REFERRAL_CODE, "Incorrect referralCode");
        assertEq(adapter.contractType(), "ADAPTER::AAVE_V3_POOL", "Incorrect contractType");
        assertEq(adapter.version(), 3_11, "Incorrect version");
    }

    /// @notice U:[A3P-2]: Wrapper functions revert on wrong caller
    function test_U_A3P_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.supply(asset, 0, address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.supplyDiff(asset, 0);

        _revertsOnNonFacadeCaller();
        adapter.withdraw(asset, 0, address(0));

        _revertsOnNonFacadeCaller();
        adapter.withdrawDiff(asset, 0);
    }

    /// @notice U:[A3P-3]: `supply` works as expected
    function test_U_A3P_03_supply_works_as_expected() public {
        _readsActiveAccount();
        _executesSwap({
            tokenIn: asset,
            callData: abi.encodeCall(IAaveV3Pool.supply, (asset, 1000, creditAccount, REFERRAL_CODE)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.supply(asset, 1000, address(0), 0);
        assertFalse(useSafePrices);
    }

    /// @notice U:[A3P-4]: `supplyDiff` works as expected
    function test_U_A3P_04_supplyDiff_works_as_expected() public diffTestCases {
        deal({token: asset, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: asset,
            callData: abi.encodeCall(IAaveV3Pool.supply, (asset, diffInputAmount, creditAccount, REFERRAL_CODE)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.supplyDiff(asset, diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[A3P-5]: `withdraw` works as expected
    function test_U_A3P_05_withdraw_works_as_expected() public {
        _readsActiveAccount();
        _executesSwap({
            tokenIn: aToken,
            callData: abi.encodeCall(IAaveV3Pool.withdraw, (asset, 1000, creditAccount)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdraw(asset, 1000, address(0));
        assertFalse(useSafePrices);
    }

    /// @notice U:[A3P-6]: `withdrawDiff` works as expected
    function test_U_A3P_06_withdrawDiff_works_as_expected() public diffTestCases {
        deal({token: aToken, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: aToken,
            callData: abi.encodeCall(IAaveV3Pool.withdraw, (asset, diffInputAmount, creditAccount)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawDiff(asset, diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[A3P-7]: supply/withdraw revert when asset is not allowlisted
    function test_U_A3P_07_reverts_when_asset_not_allowed() public {
        address unknownAsset = tokens[2];
        vm.mockCall(aavePool, abi.encodeCall(IAaveV3Pool.getReserveAToken, (unknownAsset)), abi.encode(tokens[3]));

        vm.prank(creditFacade);
        vm.expectRevert(TokenNotAllowedException.selector);
        adapter.supply(unknownAsset, 1000, address(0), 0);

        vm.prank(creditFacade);
        vm.expectRevert(TokenNotAllowedException.selector);
        adapter.withdraw(unknownAsset, 1000, address(0));
    }

    /// @notice U:[A3P-8]: `setAssetStatusBatch` works as expected
    function test_U_A3P_08_setAssetStatusBatch_works_as_expected() public {
        address newAsset = tokens[2];
        address newAToken = tokens[3];
        vm.mockCall(aavePool, abi.encodeCall(IAaveV3Pool.getReserveAToken, (newAsset)), abi.encode(newAToken));

        AaveV3AssetStatus[] memory assets = new AaveV3AssetStatus[](2);
        assets[0] = AaveV3AssetStatus({asset: asset, allowed: false});
        assets[1] = AaveV3AssetStatus({asset: newAsset, allowed: true});

        _revertsOnNonConfiguratorCaller();
        adapter.setAssetStatusBatch(assets);

        _readsTokenMask(newAsset);
        _readsTokenMask(newAToken);
        vm.expectEmit(true, false, false, true);
        emit IAaveV3PoolAdapter.SetAssetStatus(asset, false);
        vm.expectEmit(true, false, false, true);
        emit IAaveV3PoolAdapter.SetAssetStatus(newAsset, true);

        vm.prank(configurator);
        adapter.setAssetStatusBatch(assets);

        assertFalse(adapter.isAssetAllowed(asset), "Old asset should be disallowed");
        assertTrue(adapter.isAssetAllowed(newAsset), "New asset should be allowed");

        address[] memory allowed = adapter.allowedAssets();
        assertEq(allowed.length, 1, "Incorrect allowlist length");
        assertEq(allowed[0], newAsset, "Incorrect allowed asset");
    }

    /// @notice U:[A3P-9]: `serialize` works as expected
    function test_U_A3P_09_serialize_works_as_expected() public view {
        (address cm, address tc, address pool_, uint16 referral, address[] memory assets) =
            abi.decode(adapter.serialize(), (address, address, address, uint16, address[]));

        assertEq(cm, address(creditManager), "Incorrect creditManager");
        assertEq(tc, aavePool, "Incorrect targetContract");
        assertEq(pool_, aavePool, "Incorrect pool");
        assertEq(referral, REFERRAL_CODE, "Incorrect referralCode");
        assertEq(assets.length, 1, "Incorrect assets length");
        assertEq(assets[0], asset, "Incorrect asset");
    }
}
