// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KelpLRTWithdrawer} from "../../../../helpers/kelp/KelpLRTWithdrawer.sol";
import {IKelpLRTWithdrawalManager} from "../../../../integrations/kelp/IKelpLRTWithdrawalManager.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {WETHMock} from "../../../mocks/token/WETHMock.sol";

/// @title Kelp LRT withdrawer unit test
/// @notice U:[KLW]: Unit tests for Kelp LRT withdrawer
contract KelpLRTWithdrawerUnitTest is Test {
    KelpLRTWithdrawer withdrawer;

    address gateway;
    address withdrawalManager;
    address rsETH;
    address weth;
    address stETH;
    address account;

    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        gateway = address(this);
        withdrawalManager = makeAddr("WITHDRAWAL_MANAGER");
        rsETH = address(new ERC20Mock("rsETH", "rsETH", 18));
        weth = address(new WETHMock());
        stETH = address(new ERC20Mock("stETH", "stETH", 18));
        account = makeAddr("ACCOUNT");

        withdrawer = new KelpLRTWithdrawer(withdrawalManager, rsETH, weth);
        withdrawer.setAccount(account);
    }

    /// @notice U:[KLW-1]: Constructor and setAccount work as expected
    function test_U_KLW_01_constructor_and_setAccount_work() public {
        assertEq(withdrawer.gateway(), gateway);
        assertEq(withdrawer.withdrawalManager(), withdrawalManager);
        assertEq(withdrawer.rsETH(), rsETH);
        assertEq(withdrawer.weth(), weth);
        assertEq(withdrawer.account(), account);

        vm.expectRevert(KelpLRTWithdrawer.CallerNotGatewayException.selector);
        vm.prank(makeAddr("NOT_GATEWAY"));
        withdrawer.setAccount(makeAddr("NEW_ACCOUNT"));
    }

    /// @notice U:[KLW-2]: initiateWithdrawal works as expected
    function test_U_KLW_02_initiateWithdrawal_works() public {
        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.userAssociatedNonces, (stETH, address(withdrawer))),
            abi.encode(uint128(0), uint128(1))
        );

        deal(rsETH, address(withdrawer), 1000);

        vm.expectCall(
            withdrawalManager, abi.encodeCall(IKelpLRTWithdrawalManager.initiateWithdrawal, (stETH, 1000, "ref"))
        );

        withdrawer.initiateWithdrawal(stETH, 1000, "ref");

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.userAssociatedNonces, (ETH, address(withdrawer))),
            abi.encode(uint128(0), uint128(0))
        );

        vm.expectCall(
            withdrawalManager, abi.encodeCall(IKelpLRTWithdrawalManager.initiateWithdrawal, (ETH, 500, "ref"))
        );

        withdrawer.initiateWithdrawal(weth, 500, "ref");
    }

    /// @notice U:[KLW-3]: initiateWithdrawal reverts with too many requests
    function test_U_KLW_03_initiateWithdrawal_reverts_too_many_requests() public {
        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.userAssociatedNonces, (stETH, address(withdrawer))),
            abi.encode(uint128(0), uint128(5))
        );

        vm.expectRevert(KelpLRTWithdrawer.TooManyRequestsException.selector);
        withdrawer.initiateWithdrawal(stETH, 1000, "ref");
    }

    /// @notice U:[KLW-4]: completeWithdrawal works with claimable assets
    function test_U_KLW_04_completeWithdrawal_works() public {
        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.userAssociatedNonces, (stETH, address(withdrawer))),
            abi.encode(uint128(0), uint128(2))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.nextLockedNonce, (stETH)),
            abi.encode(uint256(2))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.getUserWithdrawalRequest, (stETH, address(withdrawer), 0)),
            abi.encode(uint256(0), uint256(100), uint256(0), uint256(0))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.getUserWithdrawalRequest, (stETH, address(withdrawer), 1)),
            abi.encode(uint256(0), uint256(200), uint256(0), uint256(1))
        );

        vm.expectCall(withdrawalManager, abi.encodeCall(IKelpLRTWithdrawalManager.completeWithdrawal, (stETH, "ref")));
        vm.expectCall(withdrawalManager, abi.encodeCall(IKelpLRTWithdrawalManager.completeWithdrawal, (stETH, "ref")));

        deal(stETH, address(withdrawer), 300);

        withdrawer.completeWithdrawal(stETH, 250, "ref");

        assertEq(IERC20(stETH).balanceOf(account), 250);
        assertEq(IERC20(stETH).balanceOf(address(withdrawer)), 50);
    }

    /// @notice U:[KLW-5]: completeWithdrawal works with assets already on withdrawer
    function test_U_KLW_05_completeWithdrawal_with_existing_balance() public {
        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.userAssociatedNonces, (stETH, address(withdrawer))),
            abi.encode(uint128(0), uint128(0))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.nextLockedNonce, (stETH)),
            abi.encode(uint256(0))
        );

        deal(stETH, address(withdrawer), 500);

        withdrawer.completeWithdrawal(stETH, 300, "ref");

        assertEq(IERC20(stETH).balanceOf(account), 300);
        assertEq(IERC20(stETH).balanceOf(address(withdrawer)), 200);
    }

    /// @notice U:[KLW-6]: completeWithdrawal reverts when not enough to claim
    function test_U_KLW_06_completeWithdrawal_reverts_not_enough() public {
        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.userAssociatedNonces, (stETH, address(withdrawer))),
            abi.encode(uint128(0), uint128(0))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.nextLockedNonce, (stETH)),
            abi.encode(uint256(0))
        );

        deal(stETH, address(withdrawer), 100);

        vm.expectRevert(KelpLRTWithdrawer.NotEnoughToClaimException.selector);
        withdrawer.completeWithdrawal(stETH, 200, "ref");
    }

    /// @notice U:[KLW-7]: getPendingAssetAmount works as expected
    function test_U_KLW_07_getPendingAssetAmount_works() public {
        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.userAssociatedNonces, (stETH, address(withdrawer))),
            abi.encode(uint128(0), uint128(3))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.nextLockedNonce, (stETH)),
            abi.encode(uint256(2))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.getUserWithdrawalRequest, (stETH, address(withdrawer), 0)),
            abi.encode(uint256(100), uint256(110), uint256(0), uint256(0))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.getUserWithdrawalRequest, (stETH, address(withdrawer), 1)),
            abi.encode(uint256(200), uint256(220), uint256(0), uint256(1))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.getUserWithdrawalRequest, (stETH, address(withdrawer), 2)),
            abi.encode(uint256(300), uint256(330), uint256(0), uint256(2))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.getExpectedAssetAmount, (stETH, 100)),
            abi.encode(110)
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.getExpectedAssetAmount, (stETH, 200)),
            abi.encode(220)
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.getExpectedAssetAmount, (stETH, 300)),
            abi.encode(330)
        );

        uint256 pending = withdrawer.getPendingAssetAmount(stETH);
        assertEq(pending, 330);
    }

    /// @notice U:[KLW-8]: getClaimableAssetAmount works as expected
    function test_U_KLW_08_getClaimableAssetAmount_works() public {
        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.userAssociatedNonces, (stETH, address(withdrawer))),
            abi.encode(uint128(0), uint128(2))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.nextLockedNonce, (stETH)),
            abi.encode(uint256(1))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.getUserWithdrawalRequest, (stETH, address(withdrawer), 0)),
            abi.encode(uint256(0), uint256(100), uint256(0), uint256(0))
        );

        vm.mockCall(
            withdrawalManager,
            abi.encodeCall(IKelpLRTWithdrawalManager.getUserWithdrawalRequest, (stETH, address(withdrawer), 1)),
            abi.encode(uint256(0), uint256(200), uint256(0), uint256(1))
        );

        deal(stETH, address(withdrawer), 50);

        uint256 claimable = withdrawer.getClaimableAssetAmount(stETH);
        assertEq(claimable, 150);
    }

    /// @notice U:[KLW-9]: receive function works correctly
    function test_U_KLW_09_receive_function_works() public {
        deal(account, 1 ether);

        vm.prank(account);
        (bool success,) = address(withdrawer).call{value: 1 ether}("");
        assertFalse(success);

        vm.deal(withdrawalManager, 1 ether);
        vm.prank(withdrawalManager);
        (success,) = address(withdrawer).call{value: 1 ether}("");
        assertTrue(success);

        assertEq(IERC20(weth).balanceOf(address(withdrawer)), 1 ether);
    }

    /// @notice U:[KLW-10]: Access control works as expected
    function test_U_KLW_10_access_control_works() public {
        address notGateway = makeAddr("NOT_GATEWAY");

        vm.startPrank(notGateway);

        vm.expectRevert(KelpLRTWithdrawer.CallerNotGatewayException.selector);
        withdrawer.initiateWithdrawal(stETH, 1000, "ref");

        vm.expectRevert(KelpLRTWithdrawer.CallerNotGatewayException.selector);
        withdrawer.completeWithdrawal(stETH, 1000, "ref");

        vm.stopPrank();
    }
}
