// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MellowFlexibleDepositor} from "../../../../helpers/mellow/MellowFlexibleDepositor.sol";
import {IMellowDepositQueue} from "../../../../integrations/mellow/IMellowDepositQueue.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

/// @title Mellow flexible depositor unit test
/// @notice U:[MFD]: Unit tests for Mellow flexible depositor
contract MellowFlexibleDepositorUnitTest is Test {
    MellowFlexibleDepositor depositor;

    address gateway;
    address mellowDepositQueue;
    address asset;
    address vaultToken;
    address account;
    address referral;

    function setUp() public {
        gateway = address(this);
        mellowDepositQueue = makeAddr("DEPOSIT_QUEUE");
        asset = address(new ERC20Mock("USDC", "USDC", 6));
        vaultToken = address(new ERC20Mock("Mellow Vault", "mVault", 18));
        account = makeAddr("ACCOUNT");
        referral = makeAddr("REFERRAL");

        depositor = new MellowFlexibleDepositor(mellowDepositQueue, asset, vaultToken);
        depositor.setAccount(account);
    }

    /// @notice U:[MFD-1]: Constructor and setAccount work as expected
    function test_U_MFD_01_constructor_and_setAccount_work() public {
        assertEq(depositor.gateway(), gateway);
        assertEq(depositor.mellowDepositQueue(), mellowDepositQueue);
        assertEq(depositor.asset(), asset);
        assertEq(depositor.vaultToken(), vaultToken);
        assertEq(depositor.account(), account);

        vm.expectRevert(MellowFlexibleDepositor.CallerNotGatewayException.selector);
        vm.prank(makeAddr("NOT_GATEWAY"));
        depositor.setAccount(makeAddr("NEW_ACCOUNT"));
    }

    /// @notice U:[MFD-2]: deposit works as expected
    function test_U_MFD_02_deposit_works() public {
        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.requestOf, (address(depositor))),
            abi.encode(uint256(0), uint256(0))
        );

        deal(asset, address(depositor), 1e6);

        bytes32[] memory merkleProof = new bytes32[](0);
        vm.expectCall(
            mellowDepositQueue, abi.encodeCall(IMellowDepositQueue.deposit, (uint224(1e6), referral, merkleProof))
        );

        depositor.deposit(1e6, referral);
    }

    /// @notice U:[MFD-3]: deposit reverts when deposit in progress
    function test_U_MFD_03_deposit_reverts_when_in_progress() public {
        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.requestOf, (address(depositor))),
            abi.encode(uint256(0), uint256(1000))
        );

        vm.mockCall(
            mellowDepositQueue, abi.encodeCall(IMellowDepositQueue.claimableOf, (account)), abi.encode(uint256(0))
        );

        vm.expectRevert(MellowFlexibleDepositor.DepositInProgressException.selector);
        depositor.deposit(1e6, referral);
    }

    /// @notice U:[MFD-4]: cancelDepositRequest works as expected
    function test_U_MFD_04_cancelDepositRequest_works() public {
        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.requestOf, (address(depositor))),
            abi.encode(uint256(0), uint256(1000))
        );

        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.claimableOf, (address(depositor))),
            abi.encode(uint256(0))
        );

        vm.expectCall(mellowDepositQueue, abi.encodeCall(IMellowDepositQueue.cancelDepositRequest, ()));

        deal(asset, address(depositor), 1000);

        depositor.cancelDepositRequest();

        assertEq(IERC20(asset).balanceOf(account), 1000);
        assertEq(IERC20(asset).balanceOf(address(depositor)), 0);
    }

    /// @notice U:[MFD-5]: cancelDepositRequest reverts when no deposit in progress
    function test_U_MFD_05_cancelDepositRequest_reverts_when_not_in_progress() public {
        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.requestOf, (address(depositor))),
            abi.encode(uint256(0), uint256(0))
        );

        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.claimableOf, (address(depositor))),
            abi.encode(uint256(0))
        );

        vm.expectRevert(MellowFlexibleDepositor.DepositNotInProgressException.selector);
        depositor.cancelDepositRequest();
    }

    /// @notice U:[MFD-6]: claim works with claimable shares
    function test_U_MFD_06_claim_works() public {
        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.claimableOf, (address(depositor))),
            abi.encode(uint256(300))
        );

        vm.expectCall(mellowDepositQueue, abi.encodeCall(IMellowDepositQueue.claim, (address(depositor))));

        deal(vaultToken, address(depositor), 300);

        depositor.claim(250);

        assertEq(IERC20(vaultToken).balanceOf(account), 250);
        assertEq(IERC20(vaultToken).balanceOf(address(depositor)), 50);
    }

    /// @notice U:[MFD-7]: claim works with existing balance
    function test_U_MFD_07_claim_with_existing_balance() public {
        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.claimableOf, (address(depositor))),
            abi.encode(uint256(0))
        );

        deal(vaultToken, address(depositor), 500);

        depositor.claim(300);

        assertEq(IERC20(vaultToken).balanceOf(account), 300);
        assertEq(IERC20(vaultToken).balanceOf(address(depositor)), 200);
    }

    /// @notice U:[MFD-8]: claim reverts when not enough to claim
    function test_U_MFD_08_claim_reverts_not_enough() public {
        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.claimableOf, (address(depositor))),
            abi.encode(uint256(0))
        );

        deal(vaultToken, address(depositor), 100);

        vm.expectRevert(MellowFlexibleDepositor.NotEnoughToClaimException.selector);
        depositor.claim(200);
    }

    /// @notice U:[MFD-9]: getPendingAssets works as expected
    function test_U_MFD_09_getPendingAssets_works() public {
        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.claimableOf, (address(depositor))),
            abi.encode(uint256(0))
        );

        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.requestOf, (address(depositor))),
            abi.encode(uint256(0), uint256(1000))
        );

        uint256 pending = depositor.getPendingAssets();
        assertEq(pending, 1000);

        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.claimableOf, (address(depositor))),
            abi.encode(uint256(100))
        );

        pending = depositor.getPendingAssets();
        assertEq(pending, 0);
    }

    /// @notice U:[MFD-10]: getClaimableShares works as expected
    function test_U_MFD_10_getClaimableShares_works() public {
        vm.mockCall(
            mellowDepositQueue,
            abi.encodeCall(IMellowDepositQueue.claimableOf, (address(depositor))),
            abi.encode(uint256(100))
        );

        deal(vaultToken, address(depositor), 50);

        uint256 claimable = depositor.getClaimableShares();
        assertEq(claimable, 150);
    }

    /// @notice U:[MFD-11]: Access control works as expected
    function test_U_MFD_11_access_control_works() public {
        address notGateway = makeAddr("NOT_GATEWAY");

        vm.startPrank(notGateway);

        vm.expectRevert(MellowFlexibleDepositor.CallerNotGatewayException.selector);
        depositor.deposit(1000, referral);

        vm.expectRevert(MellowFlexibleDepositor.CallerNotGatewayException.selector);
        depositor.cancelDepositRequest();

        vm.expectRevert(MellowFlexibleDepositor.CallerNotGatewayException.selector);
        depositor.claim(100);

        vm.stopPrank();
    }
}
