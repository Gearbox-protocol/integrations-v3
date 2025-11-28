// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MellowFlexibleRedeemer} from "../../../../helpers/mellow/MellowFlexibleRedeemer.sol";
import {IMellowRedeemQueue, Request} from "../../../../integrations/mellow/IMellowRedeemQueue.sol";
// Removed ERC20Mock import as we're using mock addresses

/// @title Mellow flexible redeemer unit test
/// @notice U:[MFR]: Unit tests for Mellow flexible redeemer
contract MellowFlexibleRedeemerUnitTest is Test {
    MellowFlexibleRedeemer redeemer;

    address gateway;
    address mellowRedeemQueue;
    address asset;
    address vaultToken;
    address account;

    function setUp() public {
        gateway = address(this);
        mellowRedeemQueue = makeAddr("REDEEM_QUEUE");
        asset = makeAddr("ASSET");
        vaultToken = makeAddr("VAULT_TOKEN");
        account = makeAddr("ACCOUNT");

        redeemer = new MellowFlexibleRedeemer(mellowRedeemQueue, asset, vaultToken);
        redeemer.setAccount(account);
    }

    /// @notice U:[MFR-1]: Constructor and setAccount work as expected
    function test_U_MFR_01_constructor_and_setAccount_work() public {
        assertEq(redeemer.gateway(), gateway);
        assertEq(redeemer.mellowRedeemQueue(), mellowRedeemQueue);
        assertEq(redeemer.asset(), asset);
        assertEq(redeemer.vaultToken(), vaultToken);
        assertEq(redeemer.account(), account);

        vm.expectRevert(MellowFlexibleRedeemer.CallerNotGatewayException.selector);
        vm.prank(makeAddr("NOT_GATEWAY"));
        redeemer.setAccount(makeAddr("NEW_ACCOUNT"));
    }

    /// @notice U:[MFR-2]: redeem works as expected
    function test_U_MFR_02_redeem_works() public {
        Request[] memory requests = new Request[](1);

        vm.mockCall(
            mellowRedeemQueue,
            abi.encodeCall(IMellowRedeemQueue.requestsOf, (address(redeemer), 0, type(uint256).max)),
            abi.encode(requests)
        );

        vm.expectCall(mellowRedeemQueue, abi.encodeCall(IMellowRedeemQueue.redeem, (1000)));

        redeemer.redeem(1000);
    }

    /// @notice U:[MFR-3]: redeem reverts with too many requests
    function test_U_MFR_03_redeem_reverts_too_many_requests() public {
        Request[] memory requests = new Request[](5);

        vm.mockCall(
            mellowRedeemQueue,
            abi.encodeCall(IMellowRedeemQueue.requestsOf, (address(redeemer), 0, type(uint256).max)),
            abi.encode(requests)
        );

        vm.expectRevert(MellowFlexibleRedeemer.TooManyRequestsException.selector);
        redeemer.redeem(1000);
    }

    /// @notice U:[MFR-4]: claim works with claimable assets
    function test_U_MFR_04_claim_works() public {
        Request[] memory requests = new Request[](0);

        vm.mockCall(
            mellowRedeemQueue,
            abi.encodeCall(IMellowRedeemQueue.requestsOf, (address(redeemer), 0, type(uint256).max)),
            abi.encode(requests)
        );

        vm.mockCall(asset, abi.encodeCall(IERC20.balanceOf, (address(redeemer))), abi.encode(uint256(330)));

        vm.mockCall(asset, abi.encodeCall(IERC20.transfer, (account, 300)), abi.encode(true));

        vm.expectCall(asset, abi.encodeCall(IERC20.transfer, (account, 300)));

        redeemer.claim(300);
    }

    /// @notice U:[MFR-4A]: claim works with claimable assets using mockCalls
    function test_U_MFR_04A_claim_with_queue_assets() public {
        Request[] memory requests = new Request[](2);
        requests[0] = Request({timestamp: 1000, shares: 100, assets: 110, isClaimable: true});
        requests[1] = Request({timestamp: 2000, shares: 200, assets: 220, isClaimable: true});

        vm.mockCall(
            mellowRedeemQueue,
            abi.encodeCall(IMellowRedeemQueue.requestsOf, (address(redeemer), 0, type(uint256).max)),
            abi.encode(requests)
        );

        uint32[] memory timestamps = new uint32[](2);
        timestamps[0] = 1000;
        timestamps[1] = 2000;

        vm.mockCall(
            mellowRedeemQueue,
            abi.encodeCall(IMellowRedeemQueue.claim, (address(redeemer), timestamps)),
            abi.encode(uint256(330))
        );

        bytes[] memory balanceReturns = new bytes[](2);
        balanceReturns[0] = abi.encode(uint256(0));
        balanceReturns[1] = abi.encode(uint256(330));

        vm.mockCalls(asset, abi.encodeCall(IERC20.balanceOf, (address(redeemer))), balanceReturns);

        vm.mockCall(asset, abi.encodeCall(IERC20.transfer, (account, 300)), abi.encode(true));

        vm.expectCall(mellowRedeemQueue, abi.encodeCall(IMellowRedeemQueue.claim, (address(redeemer), timestamps)));
        vm.expectCall(asset, abi.encodeCall(IERC20.transfer, (account, 300)));

        redeemer.claim(300);
    }

    /// @notice U:[MFR-5]: claim works with existing balance
    function test_U_MFR_05_claim_with_existing_balance() public {
        Request[] memory requests = new Request[](0);

        vm.mockCall(
            mellowRedeemQueue,
            abi.encodeCall(IMellowRedeemQueue.requestsOf, (address(redeemer), 0, type(uint256).max)),
            abi.encode(requests)
        );

        vm.mockCall(asset, abi.encodeCall(IERC20.balanceOf, (address(redeemer))), abi.encode(500));

        redeemer.claim(300);
    }

    /// @notice U:[MFR-6]: claim reverts when not enough to claim
    function test_U_MFR_06_claim_reverts_not_enough() public {
        Request[] memory requests = new Request[](0);

        vm.mockCall(
            mellowRedeemQueue,
            abi.encodeCall(IMellowRedeemQueue.requestsOf, (address(redeemer), 0, type(uint256).max)),
            abi.encode(requests)
        );

        vm.mockCall(asset, abi.encodeCall(IERC20.balanceOf, (address(redeemer))), abi.encode(100));

        vm.expectRevert(MellowFlexibleRedeemer.NotEnoughToClaimException.selector);
        redeemer.claim(200);
    }

    /// @notice U:[MFR-7]: getPendingShares works as expected
    function test_U_MFR_07_getPendingShares_works() public {
        Request[] memory requests = new Request[](3);
        requests[0] = Request({timestamp: 1000, shares: 100, assets: 110, isClaimable: true});
        requests[1] = Request({timestamp: 2000, shares: 200, assets: 220, isClaimable: false});
        requests[2] = Request({timestamp: 3000, shares: 300, assets: 330, isClaimable: false});

        vm.mockCall(
            mellowRedeemQueue,
            abi.encodeCall(IMellowRedeemQueue.requestsOf, (address(redeemer), 0, type(uint256).max)),
            abi.encode(requests)
        );

        uint256 pending = redeemer.getPendingShares();
        assertEq(pending, 500);
    }

    /// @notice U:[MFR-8]: getClaimableAssets works as expected
    function test_U_MFR_08_getClaimableAssets_works() public {
        Request[] memory requests = new Request[](2);
        requests[0] = Request({timestamp: 1000, shares: 100, assets: 110, isClaimable: true});
        requests[1] = Request({timestamp: 2000, shares: 200, assets: 220, isClaimable: false});

        vm.mockCall(
            mellowRedeemQueue,
            abi.encodeCall(IMellowRedeemQueue.requestsOf, (address(redeemer), 0, type(uint256).max)),
            abi.encode(requests)
        );

        vm.mockCall(asset, abi.encodeCall(IERC20.balanceOf, (address(redeemer))), abi.encode(50));

        uint256 claimable = redeemer.getClaimableAssets();
        assertEq(claimable, 160);
    }

    /// @notice U:[MFR-9]: claim correctly filters claimable requests
    function test_U_MFR_09_claim_filters_claimable_requests() public {
        Request[] memory requests = new Request[](3);
        requests[0] = Request({timestamp: 1000, shares: 100, assets: 110, isClaimable: true});
        requests[1] = Request({timestamp: 2000, shares: 200, assets: 220, isClaimable: false});
        requests[2] = Request({timestamp: 3000, shares: 300, assets: 330, isClaimable: true});

        vm.mockCall(
            mellowRedeemQueue,
            abi.encodeCall(IMellowRedeemQueue.requestsOf, (address(redeemer), 0, type(uint256).max)),
            abi.encode(requests)
        );

        uint32[] memory timestamps = new uint32[](3);
        timestamps[0] = 1000;
        timestamps[1] = 2000;
        timestamps[2] = 3000;

        vm.mockCall(
            mellowRedeemQueue,
            abi.encodeCall(IMellowRedeemQueue.claim, (address(redeemer), timestamps)),
            abi.encode(uint256(440))
        );

        bytes[] memory balanceReturns = new bytes[](2);
        balanceReturns[0] = abi.encode(uint256(0));
        balanceReturns[1] = abi.encode(uint256(440));

        vm.mockCalls(asset, abi.encodeCall(IERC20.balanceOf, (address(redeemer))), balanceReturns);

        vm.mockCall(asset, abi.encodeCall(IERC20.transfer, (account, 440)), abi.encode(true));

        vm.expectCall(mellowRedeemQueue, abi.encodeCall(IMellowRedeemQueue.claim, (address(redeemer), timestamps)));
        vm.expectCall(asset, abi.encodeCall(IERC20.transfer, (account, 440)));

        redeemer.claim(440);
    }

    /// @notice U:[MFR-10]: Access control works as expected
    function test_U_MFR_10_access_control_works() public {
        address notGateway = makeAddr("NOT_GATEWAY");

        vm.startPrank(notGateway);

        vm.expectRevert(MellowFlexibleRedeemer.CallerNotGatewayException.selector);
        redeemer.redeem(1000);

        vm.expectRevert(MellowFlexibleRedeemer.CallerNotGatewayException.selector);
        redeemer.claim(100);

        vm.stopPrank();
    }
}
