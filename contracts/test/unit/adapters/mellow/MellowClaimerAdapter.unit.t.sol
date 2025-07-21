// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {MellowClaimerAdapter} from "../../../../adapters/mellow/MellowClaimerAdapter.sol";
import {IMellowClaimer} from "../../../../integrations/mellow/IMellowClaimer.sol";
import {IMellowMultiVault, Subvault, MellowProtocol} from "../../../../integrations/mellow/IMellowMultiVault.sol";
import {IEigenLayerWithdrawalQueue} from "../../../../integrations/mellow/IMellowMultiVault.sol";
import {
    IMellowClaimerAdapter,
    IMellowClaimerAdapterExceptions,
    MellowMultivaultStatus
} from "../../../../interfaces/mellow/IMellowClaimerAdapter.sol";
import {MellowWithdrawalPhantomToken} from "../../../../helpers/mellow/MellowWithdrawalPhantomToken.sol";
import {IPhantomTokenAdapter} from "../../../../interfaces/IPhantomTokenAdapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title MellowClaimerAdapter unit test
/// @notice U:[MCA]: Unit tests for MellowClaimerAdapter
contract MellowClaimerAdapterUnitTest is AdapterUnitTestHelper, IMellowClaimerAdapterExceptions {
    MellowClaimerAdapter adapter;

    address claimer;
    address multivault1;
    address multivault2;
    address asset1;
    address asset2;
    address stakedPhantomToken1;
    address stakedPhantomToken2;
    address withdrawalQueue;

    function setUp() public {
        _setUp();

        claimer = makeAddr("CLAIMER");
        multivault1 = tokens[0];
        multivault2 = tokens[1];
        asset1 = tokens[2];
        asset2 = tokens[3];
        stakedPhantomToken1 = tokens[4];
        stakedPhantomToken2 = tokens[5];
        withdrawalQueue = makeAddr("WITHDRAWAL_QUEUE");

        // Mock multivault1
        vm.mockCall(multivault1, abi.encodeCall(IERC4626.asset, ()), abi.encode(asset1));
        vm.mockCall(multivault1, abi.encodeCall(IMellowMultiVault.subvaultsCount, ()), abi.encode(1));
        vm.mockCall(
            multivault1,
            abi.encodeCall(IMellowMultiVault.subvaultAt, (0)),
            abi.encode(
                Subvault({vault: tokens[6], withdrawalQueue: withdrawalQueue, protocol: MellowProtocol.EIGEN_LAYER})
            )
        );

        // Mock multivault2
        vm.mockCall(multivault2, abi.encodeCall(IERC4626.asset, ()), abi.encode(asset2));
        vm.mockCall(multivault2, abi.encodeCall(IMellowMultiVault.subvaultsCount, ()), abi.encode(1));
        vm.mockCall(
            multivault2,
            abi.encodeCall(IMellowMultiVault.subvaultAt, (0)),
            abi.encode(
                Subvault({vault: tokens[7], withdrawalQueue: withdrawalQueue, protocol: MellowProtocol.EIGEN_LAYER})
            )
        );

        // Mock phantom tokens
        vm.mockCall(stakedPhantomToken1, abi.encodeWithSignature("multiVault()"), abi.encode(multivault1));
        vm.mockCall(stakedPhantomToken1, abi.encodeWithSignature("getPhantomTokenInfo()"), abi.encode(claimer, asset1));
        vm.mockCall(stakedPhantomToken2, abi.encodeWithSignature("multiVault()"), abi.encode(multivault2));
        vm.mockCall(stakedPhantomToken2, abi.encodeWithSignature("getPhantomTokenInfo()"), abi.encode(claimer, asset2));

        // Mock withdrawal queue
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        vm.mockCall(
            withdrawalQueue,
            abi.encodeCall(IEigenLayerWithdrawalQueue.getAccountData, (multivault1, type(uint256).max, 0, 0, 0)),
            abi.encode(0, indices, 0)
        );
        vm.mockCall(
            withdrawalQueue,
            abi.encodeCall(IEigenLayerWithdrawalQueue.getAccountData, (multivault2, type(uint256).max, 0, 0, 0)),
            abi.encode(0, indices, 0)
        );

        adapter = new MellowClaimerAdapter(address(creditManager), claimer);
    }

    /// @notice U:[MCA-1]: Constructor works as expected
    function test_U_MCA_01_constructor_works_as_expected() public {
        adapter = new MellowClaimerAdapter(address(creditManager), claimer);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), claimer, "Incorrect targetContract");
        assertEq(adapter.allowedMultivaults().length, 0, "Should have no allowed multivaults initially");
    }

    /// @notice U:[MCA-2]: Wrapper functions revert on wrong caller
    function test_U_MCA_02_wrapper_functions_revert_on_wrong_caller() public {
        uint256[] memory subvaultIndices = new uint256[](0);
        uint256[][] memory indices = new uint256[][](0);

        _revertsOnNonFacadeCaller();
        adapter.multiAccept(multivault1, subvaultIndices, indices);

        _revertsOnNonFacadeCaller();
        adapter.multiAcceptAndClaim(multivault1, subvaultIndices, indices, address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(stakedPhantomToken1, 0);

        _revertsOnNonFacadeCaller();
        adapter.depositPhantomToken(stakedPhantomToken1, 0);
    }

    /// @notice U:[MCA-3]: `multiAccept` works as expected
    function test_U_MCA_03_multiAccept_works_as_expected() public {
        // Setup allowed multivault
        MellowMultivaultStatus[] memory multivaults = new MellowMultivaultStatus[](1);
        multivaults[0] = MellowMultivaultStatus(multivault1, stakedPhantomToken1, true);

        _readsTokenMask(stakedPhantomToken1);
        _readsTokenMask(asset1);
        vm.prank(configurator);
        adapter.setMultivaultStatusBatch(multivaults);

        uint256[] memory subvaultIndices = new uint256[](1);
        subvaultIndices[0] = 0;
        uint256[][] memory indices = new uint256[][](1);
        indices[0] = new uint256[](2);
        indices[0][0] = 0;
        indices[0][1] = 1;

        // Test with non-allowed multivault
        vm.expectRevert(MultivaultNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.multiAccept(multivault2, subvaultIndices, indices);

        // Test with allowed multivault
        _executesCall({
            tokensToApprove: new address[](0),
            callData: abi.encodeCall(
                IMellowClaimer.multiAcceptAndClaim, (multivault1, subvaultIndices, indices, address(0), 0)
            )
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.multiAccept(multivault1, subvaultIndices, indices);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MCA-4]: `multiAcceptAndClaim` works as expected
    function test_U_MCA_04_multiAcceptAndClaim_works_as_expected() public {
        // Setup allowed multivault
        MellowMultivaultStatus[] memory multivaults = new MellowMultivaultStatus[](1);
        multivaults[0] = MellowMultivaultStatus(multivault1, stakedPhantomToken1, true);
        _readsTokenMask(stakedPhantomToken1);
        _readsTokenMask(asset1);
        vm.prank(configurator);
        adapter.setMultivaultStatusBatch(multivaults);

        uint256[] memory subvaultIndices = new uint256[](1);
        subvaultIndices[0] = 0;
        uint256[][] memory indices = new uint256[][](1);
        indices[0] = new uint256[](2);
        indices[0][0] = 0;
        indices[0][1] = 1;

        // Test with non-allowed multivault
        vm.expectRevert(MultivaultNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.multiAcceptAndClaim(multivault2, subvaultIndices, indices, address(0), 1000);

        // Test successful claim
        _readsActiveAccount();
        deal(asset1, creditAccount, 1000); // Simulate claim result
        vm.mockCall(asset1, abi.encodeCall(IERC20.balanceOf, (creditAccount)), abi.encode(0));
        _executesCall({
            tokensToApprove: new address[](0),
            callData: abi.encodeCall(
                IMellowClaimer.multiAcceptAndClaim, (multivault1, subvaultIndices, indices, creditAccount, 1000)
            )
        });

        bytes[] memory retdatas = new bytes[](2);

        retdatas[0] = abi.encode(2000);
        retdatas[1] = abi.encode(3000);

        vm.mockCalls(asset1, abi.encodeCall(IERC20.balanceOf, (creditAccount)), retdatas);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.multiAcceptAndClaim(multivault1, subvaultIndices, indices, address(0), 1000);
        assertFalse(useSafePrices);

        retdatas[0] = abi.encode(2000);
        retdatas[1] = abi.encode(2500);

        vm.mockCalls(asset1, abi.encodeCall(IERC20.balanceOf, (creditAccount)), retdatas);

        // Test insufficient claim
        _executesCall({
            tokensToApprove: new address[](0),
            callData: abi.encodeCall(
                IMellowClaimer.multiAcceptAndClaim, (multivault1, subvaultIndices, indices, creditAccount, 1000)
            )
        });
        vm.mockCall(asset1, abi.encodeCall(IERC20.balanceOf, (creditAccount)), abi.encode(500));
        vm.expectRevert(InsufficientClaimedException.selector);
        vm.prank(creditFacade);
        adapter.multiAcceptAndClaim(multivault1, subvaultIndices, indices, address(0), 1000);
    }

    /// @notice U:[MCA-5]: `withdrawPhantomToken` works as expected
    function test_U_MCA_05_withdrawPhantomToken_works_as_expected() public {
        // Setup allowed multivault
        MellowMultivaultStatus[] memory multivaults = new MellowMultivaultStatus[](1);
        multivaults[0] = MellowMultivaultStatus(multivault1, stakedPhantomToken1, true);
        _readsTokenMask(stakedPhantomToken1);
        _readsTokenMask(asset1);
        vm.prank(configurator);
        adapter.setMultivaultStatusBatch(multivaults);

        // Test with non-allowed phantom token
        vm.expectRevert(MultivaultNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.withdrawPhantomToken(stakedPhantomToken2, 1000);

        // Test successful withdrawal
        _readsActiveAccount();
        (uint256[] memory subvaultIndices, uint256[][] memory indices) = adapter.getSubvaultIndices(multivault1);
        deal(asset1, creditAccount, 1000); // Simulate claim result
        vm.mockCall(asset1, abi.encodeCall(IERC20.balanceOf, (creditAccount)), abi.encode(0));
        _executesCall({
            tokensToApprove: new address[](0),
            callData: abi.encodeCall(
                IMellowClaimer.multiAcceptAndClaim, (multivault1, subvaultIndices, indices, creditAccount, 1000)
            )
        });

        bytes[] memory retdatas = new bytes[](2);

        retdatas[0] = abi.encode(2000);
        retdatas[1] = abi.encode(3000);

        vm.mockCalls(asset1, abi.encodeCall(IERC20.balanceOf, (creditAccount)), retdatas);
        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawPhantomToken(stakedPhantomToken1, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MCA-6]: `depositPhantomToken` reverts as expected
    function test_U_MCA_06_depositPhantomToken_reverts_as_expected() public {
        vm.expectRevert(NotImplementedException.selector);
        vm.prank(creditFacade);
        adapter.depositPhantomToken(stakedPhantomToken1, 1000);
    }

    /// @notice U:[MCA-7]: `getSubvaultIndices` works as expected
    function test_U_MCA_07_getSubvaultIndices_works_as_expected() public {
        (uint256[] memory subvaultIndices, uint256[][] memory withdrawalIndices) =
            adapter.getSubvaultIndices(multivault1);

        assertEq(subvaultIndices.length, 1, "Incorrect subvaultIndices length");
        assertEq(subvaultIndices[0], 0, "Incorrect subvault index");
        assertEq(withdrawalIndices.length, 1, "Incorrect withdrawalIndices length");
        assertEq(withdrawalIndices[0].length, 2, "Incorrect withdrawal indices length");
        assertEq(withdrawalIndices[0][0], 0, "Incorrect withdrawal index 0");
        assertEq(withdrawalIndices[0][1], 1, "Incorrect withdrawal index 1");
    }

    /// @notice U:[MCA-8]: `setMultivaultStatusBatch` works as expected
    function test_U_MCA_08_setMultivaultStatusBatch_works_as_expected() public {
        _revertsOnNonConfiguratorCaller();
        adapter.setMultivaultStatusBatch(new MellowMultivaultStatus[](0));

        // Test adding multivaults
        MellowMultivaultStatus[] memory multivaults = new MellowMultivaultStatus[](2);
        multivaults[0] = MellowMultivaultStatus(multivault1, stakedPhantomToken1, true);
        multivaults[1] = MellowMultivaultStatus(multivault2, stakedPhantomToken2, true);

        _readsTokenMask(stakedPhantomToken1);
        _readsTokenMask(asset1);
        _readsTokenMask(stakedPhantomToken2);
        _readsTokenMask(asset2);

        vm.prank(configurator);
        adapter.setMultivaultStatusBatch(multivaults);

        address[] memory allowedMultivaults = adapter.allowedMultivaults();
        assertEq(allowedMultivaults.length, 2, "Incorrect allowed multivaults length");
        assertTrue(_contains(allowedMultivaults, multivault1), "Multivault1 not found");
        assertTrue(_contains(allowedMultivaults, multivault2), "Multivault2 not found");

        assertEq(
            adapter.phantomTokenToMultivault(stakedPhantomToken1), multivault1, "Incorrect phantom token mapping 1"
        );
        assertEq(
            adapter.phantomTokenToMultivault(stakedPhantomToken2), multivault2, "Incorrect phantom token mapping 2"
        );

        // Test removing multivault
        multivaults = new MellowMultivaultStatus[](1);
        multivaults[0] = MellowMultivaultStatus(multivault1, stakedPhantomToken1, false);

        vm.prank(configurator);
        adapter.setMultivaultStatusBatch(multivaults);

        allowedMultivaults = adapter.allowedMultivaults();
        assertEq(allowedMultivaults.length, 1, "Incorrect allowed multivaults length after removal");
        assertFalse(_contains(allowedMultivaults, multivault1), "Multivault1 should be removed");
        assertTrue(_contains(allowedMultivaults, multivault2), "Multivault2 should remain");

        // Test invalid multivault (phantom token doesn't match)
        vm.mockCall(stakedPhantomToken1, abi.encodeWithSignature("multiVault()"), abi.encode(multivault2));
        multivaults[0] = MellowMultivaultStatus(multivault1, stakedPhantomToken1, true);

        vm.expectRevert(InvalidMultivaultException.selector);
        vm.prank(configurator);
        adapter.setMultivaultStatusBatch(multivaults);
    }

    /// @notice U:[MCA-9]: `serialize` works as expected
    function test_U_MCA_09_serialize_works_as_expected() public {
        // Add some multivaults
        MellowMultivaultStatus[] memory multivaults = new MellowMultivaultStatus[](2);
        multivaults[0] = MellowMultivaultStatus(multivault1, stakedPhantomToken1, true);
        multivaults[1] = MellowMultivaultStatus(multivault2, stakedPhantomToken2, true);

        _readsTokenMask(stakedPhantomToken1);
        _readsTokenMask(asset1);
        _readsTokenMask(stakedPhantomToken2);
        _readsTokenMask(asset2);

        vm.prank(configurator);
        adapter.setMultivaultStatusBatch(multivaults);

        bytes memory serialized = adapter.serialize();
        (address cm, address tc, address[] memory allowed) = abi.decode(serialized, (address, address, address[]));

        assertEq(cm, address(creditManager), "Incorrect credit manager in serialized data");
        assertEq(tc, claimer, "Incorrect target contract in serialized data");
        assertEq(allowed.length, 2, "Incorrect allowed multivaults length in serialized data");
        assertTrue(_contains(allowed, multivault1), "Multivault1 not in serialized data");
        assertTrue(_contains(allowed, multivault2), "Multivault2 not in serialized data");
    }

    /// @dev Helper function to check if an address is in an array
    function _contains(address[] memory array, address value) internal pure returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) return true;
        }
        return false;
    }
}
