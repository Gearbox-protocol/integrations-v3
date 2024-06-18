// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {BalancerV2VaultAdapter} from "../../../../adapters/balancer/BalancerV2VaultAdapter.sol";
import {
    IAsset,
    IBalancerV2Vault,
    SwapKind,
    SingleSwap,
    FundManagement,
    BatchSwapStep,
    JoinPoolRequest,
    ExitPoolRequest
} from "../../../../integrations/balancer/IBalancerV2Vault.sol";
import {
    IBalancerV2VaultAdapterEvents,
    IBalancerV2VaultAdapterExceptions,
    PoolStatus,
    SingleSwapDiff
} from "../../../../interfaces/balancer/IBalancerV2VaultAdapter.sol";

import {VaultMock} from "../../../mocks/integrations/balancer/VaultMock.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Balancer v2 vault adapter unit test
/// @notice U:[BAL2]: Unit tests for Balancer v2 vault adapter
contract BalancerV2VaultAdapterUnitTest is
    AdapterUnitTestHelper,
    IBalancerV2VaultAdapterEvents,
    IBalancerV2VaultAdapterExceptions
{
    BalancerV2VaultAdapter adapter;

    VaultMock vault;

    bytes32 poolId = "POOL ID";
    bytes32 pool2Id = "POOL 2 ID";

    function setUp() public {
        _setUp();

        vault = new VaultMock();
        vault.setPoolData(poolId, tokens[0], _assets(0, 1, 2, 3));
        vault.setPoolData(pool2Id, tokens[4], _assets(5, 6));

        adapter = new BalancerV2VaultAdapter(address(creditManager), address(vault));
    }

    /// @notice U:[BAL2-1]: Constructor works as expected
    function test_U_BAL2_01_constructor_works_as_expected() public {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(vault), "Incorrect targetContract");
    }

    /// @notice U:[BAL2-2]: Wrapper functions revert on wrong caller
    function test_U_BAL2_02_wrapper_functions_revert_on_wrong_caller() public {
        IAsset asset;
        SwapKind swapKind;
        IAsset[] memory assets;
        int256[] memory limits;
        SingleSwap memory singleSwap;
        SingleSwapDiff memory singleSwapDiff;
        FundManagement memory fundManagement;
        BatchSwapStep[] memory batchSwapSteps;
        JoinPoolRequest memory joinPoolRequest;
        ExitPoolRequest memory exitPoolRequest;

        _revertsOnNonFacadeCaller();
        adapter.swap(singleSwap, fundManagement, 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.swapDiff(singleSwapDiff, 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.batchSwap(swapKind, batchSwapSteps, assets, fundManagement, limits, 0);

        _revertsOnNonFacadeCaller();
        adapter.joinPool(bytes32(0), address(0), address(0), joinPoolRequest);

        _revertsOnNonFacadeCaller();
        adapter.joinPoolSingleAsset(bytes32(0), asset, 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.joinPoolSingleAssetDiff(bytes32(0), asset, 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.exitPool(bytes32(0), address(0), payable(0), exitPoolRequest);

        _revertsOnNonFacadeCaller();
        adapter.exitPoolSingleAsset(bytes32(0), asset, 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.exitPoolSingleAssetDiff(bytes32(0), asset, 0, 0);
    }

    // ----- //
    // SWAPS //
    // ----- //

    /// @notice U:[BAL2-3]: `swap` works as expected
    function test_U_BAL2_03_swap_works_as_expected() public {
        SingleSwap memory singleSwap = SingleSwap({
            poolId: poolId,
            kind: SwapKind.GIVEN_IN,
            assetIn: _asset(1),
            assetOut: _asset(2),
            amount: 1000,
            userData: "DUMMY DATA"
        });

        vm.expectRevert(PoolNotSupportedException.selector);
        vm.prank(creditFacade);
        adapter.swap(singleSwap, _getFundManagement(address(0)), 0, 0);

        vm.prank(configurator);
        adapter.setPoolStatus(poolId, PoolStatus.ALLOWED);

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[1],
            tokenOut: tokens[2],
            callData: abi.encodeCall(IBalancerV2Vault.swap, (singleSwap, _getFundManagement(creditAccount), 500, 456)),
            requiresApproval: true,
            validatesTokens: true
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.swap(singleSwap, _getFundManagement(address(0)), 500, 456);

        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[BAL2-4]: `swapDiff` works as expected
    function test_U_BAL2_04_swapDiff_works_as_expected() public diffTestCases {
        deal({token: tokens[1], to: creditAccount, give: diffMintedAmount});

        SingleSwapDiff memory singleSwapDiff = SingleSwapDiff({
            poolId: poolId,
            assetIn: _asset(1),
            assetOut: _asset(2),
            leftoverAmount: diffLeftoverAmount,
            userData: "DUMMY DATA"
        });

        SingleSwap memory singleSwap = SingleSwap({
            poolId: poolId,
            kind: SwapKind.GIVEN_IN,
            assetIn: _asset(1),
            assetOut: _asset(2),
            amount: diffInputAmount,
            userData: "DUMMY DATA"
        });

        vm.expectRevert(PoolNotSupportedException.selector);
        vm.prank(creditFacade);
        adapter.swapDiff(singleSwapDiff, 0, 0);

        vm.prank(configurator);
        adapter.setPoolStatus(poolId, PoolStatus.ALLOWED);

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[1],
            tokenOut: tokens[2],
            callData: abi.encodeCall(
                IBalancerV2Vault.swap, (singleSwap, _getFundManagement(creditAccount), diffInputAmount / 2, 456)
            ),
            requiresApproval: true,
            validatesTokens: true
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.swapDiff(singleSwapDiff, 0.5e27, 456);

        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 2 : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[BAL2-5]: `batchSwap` works as expected
    function test_U_BAL2_05_batchSwap_works_as_expected() public {
        BatchSwapStep[] memory swaps = new BatchSwapStep[](2);
        swaps[0] =
            BatchSwapStep({poolId: poolId, assetInIndex: 0, assetOutIndex: 1, amount: 1000, userData: "DUMMY_DATA"});
        swaps[1] =
            BatchSwapStep({poolId: pool2Id, assetInIndex: 2, assetOutIndex: 3, amount: 1000, userData: "DUMMY_DATA"});

        IAsset[] memory assets = _assets(1, 3, 5, 6);
        int256[] memory limits = new int256[](4);
        limits[0] = 1000;
        limits[1] = -500;
        limits[2] = 1000;
        limits[3] = -500;

        creditManager.setExecuteResult(abi.encode(limits));

        vm.expectRevert(PoolNotSupportedException.selector);
        vm.prank(creditFacade);
        adapter.batchSwap(SwapKind.GIVEN_IN, swaps, assets, _getFundManagement(address(0)), limits, 456);

        vm.startPrank(configurator);
        adapter.setPoolStatus(poolId, PoolStatus.ALLOWED);
        adapter.setPoolStatus(pool2Id, PoolStatus.SWAP_ONLY);
        vm.stopPrank();

        address[] memory tokensToApprove = new address[](2);
        tokensToApprove[0] = tokens[1];
        tokensToApprove[1] = tokens[5];
        _readsActiveAccount();
        _executesCall({
            tokensToApprove: tokensToApprove,
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(
                IBalancerV2Vault.batchSwap,
                (SwapKind.GIVEN_IN, swaps, assets, _getFundManagement(creditAccount), limits, 456)
            )
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.batchSwap(SwapKind.GIVEN_IN, swaps, assets, _getFundManagement(address(0)), limits, 456);
        assertEq(tokensToEnable, 8 + 64, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    // ----- //
    // JOINS //
    // ----- //

    /// @notice U:[BAL2-6]: `joinPool` works as expected
    function test_U_BAL2_06_joinPool_works_as_expected() public {
        JoinPoolRequest memory request;
        request.assets = _assets(0, 1, 2, 3);
        request.maxAmountsIn = new uint256[](4);
        request.maxAmountsIn[1] = 500;
        request.maxAmountsIn[3] = 800;
        request.userData = "DUMMY DATA";
        request.fromInternalBalance = false;

        vm.expectRevert(PoolNotSupportedException.selector);
        vm.prank(creditFacade);
        adapter.joinPool(poolId, address(0), address(0), request);

        vm.prank(configurator);
        adapter.setPoolStatus(poolId, PoolStatus.SWAP_ONLY);

        vm.expectRevert(PoolNotSupportedException.selector);
        vm.prank(creditFacade);
        adapter.joinPool(poolId, address(0), address(0), request);

        vm.prank(configurator);
        adapter.setPoolStatus(poolId, PoolStatus.ALLOWED);

        address[] memory tokensToApprove = new address[](2);
        tokensToApprove[0] = tokens[1];
        tokensToApprove[1] = tokens[3];
        address[] memory tokensToValidate = new address[](1);
        tokensToValidate[0] = tokens[0];

        _readsActiveAccount();
        _executesCall({
            tokensToApprove: tokensToApprove,
            tokensToValidate: tokensToValidate,
            callData: abi.encodeCall(IBalancerV2Vault.joinPool, (poolId, creditAccount, creditAccount, request))
        });

        vm.prank(creditFacade);
        request.fromInternalBalance = true;
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.joinPool(poolId, address(0), address(0), request);
        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[BAL2-7]: `joinPoolSingleAsset` works as expected
    function test_U_BAL2_07_joinPoolSingleAsset_works_as_expected() public {
        vm.expectRevert(PoolNotSupportedException.selector);
        vm.prank(creditFacade);
        adapter.joinPoolSingleAsset(poolId, _asset(2), 1000, 500);

        vm.prank(configurator);
        adapter.setPoolStatus(poolId, PoolStatus.SWAP_ONLY);

        vm.expectRevert(PoolNotSupportedException.selector);
        vm.prank(creditFacade);
        adapter.joinPoolSingleAsset(poolId, _asset(2), 1000, 500);

        vm.prank(configurator);
        adapter.setPoolStatus(poolId, PoolStatus.ALLOWED);

        JoinPoolRequest memory request;
        request.assets = _assets(0, 1, 2, 3);
        request.maxAmountsIn = new uint256[](4);
        request.maxAmountsIn[2] = 1000;

        uint256[] memory maxAmountsInWithoutBPT = new uint256[](3);
        maxAmountsInWithoutBPT[1] = 1000;
        request.userData = abi.encode(uint256(1), maxAmountsInWithoutBPT, 500);

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[2],
            tokenOut: tokens[0],
            callData: abi.encodeCall(IBalancerV2Vault.joinPool, (poolId, creditAccount, creditAccount, request)),
            requiresApproval: true,
            validatesTokens: true
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.joinPoolSingleAsset(poolId, _asset(2), 1000, 500);
        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[BAL2-8]: `joinPoolSingleAssetDiff` works as expected
    function test_U_BAL2_08_joinPoolSingleAssetDiff_works_as_expected() public diffTestCases {
        deal({token: tokens[2], to: creditAccount, give: diffMintedAmount});

        vm.expectRevert(PoolNotSupportedException.selector);
        vm.prank(creditFacade);
        adapter.joinPoolSingleAssetDiff(poolId, _asset(2), diffLeftoverAmount, 0.5e27);

        vm.prank(configurator);
        adapter.setPoolStatus(poolId, PoolStatus.SWAP_ONLY);

        vm.expectRevert(PoolNotSupportedException.selector);
        vm.prank(creditFacade);
        adapter.joinPoolSingleAssetDiff(poolId, _asset(2), diffLeftoverAmount, 0.5e27);

        vm.prank(configurator);
        adapter.setPoolStatus(poolId, PoolStatus.ALLOWED);

        JoinPoolRequest memory request;
        request.assets = _assets(0, 1, 2, 3);
        request.maxAmountsIn = new uint256[](4);
        request.maxAmountsIn[2] = diffInputAmount;

        uint256[] memory maxAmountsInWithoutBPT = new uint256[](3);
        maxAmountsInWithoutBPT[1] = diffInputAmount;
        request.userData = abi.encode(uint256(1), maxAmountsInWithoutBPT, diffInputAmount / 2);

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[2],
            tokenOut: tokens[0],
            callData: abi.encodeCall(IBalancerV2Vault.joinPool, (poolId, creditAccount, creditAccount, request)),
            requiresApproval: true,
            validatesTokens: true
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.joinPoolSingleAssetDiff(poolId, _asset(2), diffLeftoverAmount, 0.5e27);
        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 4 : 0, "Incorrect tokensToDisable");
    }

    // ----- //
    // EXITS //
    // ----- //

    /// @notice U:[BAL2-9]: `exitPool` works as expected
    function test_U_BAL2_09_exitPool_works_as_expected() public {
        deal({token: tokens[1], to: creditAccount, give: 2});
        deal({token: tokens[3], to: creditAccount, give: 2});

        ExitPoolRequest memory request;
        request.assets = _assets(0, 1, 2, 3);

        address[] memory tokensToValidate = new address[](1);
        tokensToValidate[0] = tokens[0];

        _readsActiveAccount();
        _executesCall({
            tokensToApprove: new address[](0),
            tokensToValidate: tokensToValidate,
            callData: abi.encodeCall(IBalancerV2Vault.exitPool, (poolId, creditAccount, payable(creditAccount), request))
        });

        vm.prank(creditFacade);
        request.toInternalBalance = true;
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exitPool(poolId, address(0), payable(0), request);
        assertEq(tokensToEnable, 2 + 8, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[BAL2-10]: `exitPoolSingleAsset` works as expected
    function test_U_BAL2_10_exitPoolSingleAsset_works_as_expected() public {
        ExitPoolRequest memory request;
        request.assets = _assets(0, 1, 2, 3);
        request.minAmountsOut = new uint256[](4);
        request.minAmountsOut[2] = 500;
        request.userData = abi.encode(uint256(0), 1000, 1);

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[2],
            callData: abi.encodeCall(IBalancerV2Vault.exitPool, (poolId, creditAccount, payable(creditAccount), request)),
            requiresApproval: false,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exitPoolSingleAsset(poolId, _asset(2), 1000, 500);

        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[BAL2-11]: `exitPoolSingleAssetDiff` works as expected
    function test_U_BAL2_11_exitPoolSingleAssetDiff_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        ExitPoolRequest memory request;
        request.assets = _assets(0, 1, 2, 3);
        request.minAmountsOut = new uint256[](4);
        request.minAmountsOut[2] = diffInputAmount / 2;
        request.userData = abi.encode(uint256(0), diffInputAmount, 1);

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[2],
            callData: abi.encodeCall(IBalancerV2Vault.exitPool, (poolId, creditAccount, payable(creditAccount), request)),
            requiresApproval: false,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.exitPoolSingleAssetDiff(poolId, _asset(2), diffLeftoverAmount, 0.5e27);

        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 1 : 0, "Incorrect tokensToDisable");
    }

    // ------- //
    // CONFIG //
    // ------ //

    /// @notice U:[BAL2-12]: `setPoolStatus` works as expected
    function test_U_BAL2_12_setPoolStatus_works_as_expected() public {
        _revertsOnNonConfiguratorCaller();
        adapter.setPoolStatus(poolId, PoolStatus.ALLOWED);

        vm.expectEmit(true, false, false, true);
        emit SetPoolStatus(poolId, PoolStatus.ALLOWED);

        vm.prank(configurator);
        adapter.setPoolStatus(poolId, PoolStatus.ALLOWED);
        assertEq(uint256(adapter.poolStatus(poolId)), uint256(PoolStatus.ALLOWED));

        bytes32[] memory poolIds = adapter.supportedPoolIds();

        assertEq(poolIds.length, 1, "Pool ID set length incorrect");

        assertEq(poolIds[0], poolId, "Pool ID #0 incorrect");
    }

    // ------- //
    // HELPERS //
    // ------- //

    function _asset(uint256 index) internal view returns (IAsset) {
        return IAsset(tokens[index]);
    }

    function _assets() internal view returns (IAsset[] memory) {}

    function _assets(uint256 i) internal view returns (IAsset[] memory assets) {
        assets = new IAsset[](1);
        assets[0] = _asset(i);
    }

    function _assets(uint256 i1, uint256 i2) internal view returns (IAsset[] memory assets) {
        assets = new IAsset[](2);
        assets[0] = _asset(i1);
        assets[1] = _asset(i2);
    }

    function _assets(uint256 i1, uint256 i2, uint256 i3) internal view returns (IAsset[] memory assets) {
        assets = new IAsset[](3);
        assets[0] = _asset(i1);
        assets[1] = _asset(i2);
        assets[2] = _asset(i3);
    }

    function _assets(uint256 i1, uint256 i2, uint256 i3, uint256 i4) internal view returns (IAsset[] memory assets) {
        assets = new IAsset[](4);
        assets[0] = _asset(i1);
        assets[1] = _asset(i2);
        assets[2] = _asset(i3);
        assets[3] = _asset(i4);
    }

    function _getFundManagement(address creditAccount) internal pure returns (FundManagement memory) {
        return FundManagement({
            sender: creditAccount,
            fromInternalBalance: false,
            recipient: payable(creditAccount),
            toInternalBalance: false
        });
    }
}
