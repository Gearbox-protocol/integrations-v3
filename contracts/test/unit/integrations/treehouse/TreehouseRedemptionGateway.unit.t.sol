// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {IAddressProvider} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAddressProvider.sol";

import {TreehouseRedemptionGateway} from "../../../../integrations/treehouse/TreehouseRedemptionGateway.sol";
import {TreehouseRedemptionPhantomToken} from "../../../../integrations/treehouse/TreehouseRedemptionPhantomToken.sol";
import {TreehouseRedeemer} from "../../../../integrations/treehouse/TreehouseRedeemer.sol";
import {
    ITreehouseRedemptionGateway
} from "../../../../integrations/treehouse/interfaces/ITreehouseRedemptionGateway.sol";
import {ITreehouseTransferMaster} from "../../../../integrations/treehouse/interfaces/ITreehouseTransferMaster.sol";
import {IWstETH} from "../../../../integrations/treehouse/interfaces/external/IWstETH.sol";
import {RedemptionLogger} from "../../../../integrations/common/RedemptionLogger.sol";
import {
    IRedemptionLogger,
    AP_REDEMPTION_LOGGER
} from "../../../../integrations/common/interfaces/IRedemptionLogger.sol";

import {TreehouseRedemptionV3Mock, TreehouseVaultMock} from "./TreehouseRedemptionV3Mock.sol";

contract TreehouseTransferMasterMock is ITreehouseTransferMaster {
    address public override transferableRedeemerOwner;

    bytes32 public constant override contractType = "MOCK::TRANSFER_MASTER";
    uint256 public constant override version = 3_10;

    function setTransferAllowed(address account) external {
        transferableRedeemerOwner = account;
    }

    function isTransferAllowed(address redeemerOwner) external view override returns (bool) {
        return redeemerOwner == transferableRedeemerOwner;
    }
}

    contract RedemptionLoggerAddressProviderMock is IAddressProvider {
        address internal _redemptionLogger;

        constructor(address redemptionLogger_) {
            _redemptionLogger = redemptionLogger_;
        }

        function getAddressOrRevert(bytes32 key, uint256 version) external view returns (address) {
            if (key == AP_REDEMPTION_LOGGER && version == 3_10) return _redemptionLogger;
            revert("Address not found");
        }
    }

    /// @title TreehouseRedemptionGateway unit test
    /// @notice U:[TH-G]: Unit tests for TreehouseRedemptionGateway
    contract TreehouseRedemptionGatewayUnitTest is Test {
        TreehouseRedemptionGateway gateway;
        TreehouseRedemptionV3Mock redemptionV3;
        TreehouseVaultMock vault;
        TreehouseTransferMasterMock transferMaster;
        RedemptionLogger redemptionLogger;
        RedemptionLoggerAddressProviderMock addressProvider;

        ERC20Mock tAsset;
        ERC20Mock vaultUnderlying;

        address account;
        address newAccount;

        uint256 constant SHARES = 100e18;
        uint256 constant AMOUNT_AFTER_FEE = 98.5e18;

        function setUp() public {
            account = makeAddr("ACCOUNT");
            newAccount = makeAddr("NEW_ACCOUNT");

            tAsset = new ERC20Mock("tAsset", "tASSET", 18);
            vaultUnderlying = new ERC20Mock("wstETH", "wstETH", 18);
            vault = new TreehouseVaultMock(address(vaultUnderlying));
            redemptionV3 = new TreehouseRedemptionV3Mock(address(tAsset), address(vault));
            vaultUnderlying.mint(address(redemptionV3), 1_000_000e18);
            transferMaster = new TreehouseTransferMasterMock();

            redemptionLogger = new RedemptionLogger(address(this));
            addressProvider = new RedemptionLoggerAddressProviderMock(address(redemptionLogger));

            gateway =
                new TreehouseRedemptionGateway(address(redemptionV3), address(transferMaster), address(addressProvider));
            redemptionLogger.setGatewayAllowed(address(gateway), true);

            vm.mockCall(address(vaultUnderlying), abi.encodeCall(IWstETH.stEthPerToken, ()), abi.encode(uint256(1e18)));
        }

        function _redeemAs(address caller, uint256 shares) internal returns (address redeemer) {
            tAsset.mint(caller, shares);
            vm.startPrank(caller);
            IERC20(tAsset).approve(address(gateway), shares);
            gateway.redeem(shares, "");
            vm.stopPrank();

            address[] memory redeemers = gateway.pendingRedeemers(caller);
            redeemer = redeemers[redeemers.length - 1];
            vm.mockCall(address(tAsset), abi.encodeCall(IERC4626.convertToAssets, (shares)), abi.encode(shares));
        }

        /// @notice U:[TH-G-1]: Constructor works as expected
        function test_U_TH_G_01_constructor_works() public view {
            assertEq(gateway.contractType(), "GATEWAY::TREEHOUSE_REDEMPTION", "Incorrect contract type");
            assertEq(gateway.version(), 3_10, "Incorrect version");
            assertEq(gateway.redemptionV3(), address(redemptionV3), "Incorrect redemptionV3");
            assertEq(gateway.tAsset(), address(tAsset), "Incorrect tAsset");
            assertEq(gateway.vaultUnderlying(), address(vaultUnderlying), "Incorrect vaultUnderlying");
            assertEq(gateway.transferMaster(), address(transferMaster), "Incorrect transfer master");
            assertTrue(gateway.masterRedeemer() != address(0), "Master redeemer not set");
            assertTrue(gateway.phantomToken() != address(0), "Phantom token not deployed");
            assertEq(gateway.redemptionLogger(), address(redemptionLogger), "Incorrect redemption logger");

            TreehouseRedemptionPhantomToken phantomToken = TreehouseRedemptionPhantomToken(gateway.phantomToken());
            assertEq(phantomToken.gateway(), address(gateway), "Incorrect PT gateway");
            assertEq(phantomToken.contractType(), "PHANTOM_TOKEN::TREEHOUSE_RD", "Incorrect PT type");
        }

        /// @notice U:[TH-G-2]: `redeem` creates a pending redeemer and pulls tAsset
        function test_U_TH_G_02_redeem_works() public {
            address redeemer = _redeemAs(account, SHARES);

            assertEq(gateway.pendingRedeemers(account).length, 1, "Incorrect pending count");
            assertEq(gateway.redeemers(account).length, 1, "Incorrect redeemers count");
            assertEq(TreehouseRedeemer(redeemer).account(), account, "Incorrect redeemer account");
            assertTrue(TreehouseRedeemer(redeemer).alreadyRedeemed(), "Redeemer should be redeemed");
            assertEq(tAsset.balanceOf(address(redemptionV3)), SHARES, "tAsset not pulled by redemptionV3");
        }

        /// @notice U:[TH-G-3]: `finalizeRedeem` clears pending status and sends underlying to the account
        function test_U_TH_G_03_finalizeRedeem_works() public {
            address redeemer = _redeemAs(account, SHARES);

            vm.prank(account);
            gateway.finalizeRedeem(redeemer);

            assertEq(gateway.pendingRedeemers(account).length, 0, "Should leave pending set");
            assertEq(gateway.redeemers(account).length, 1, "Should remain in redeemers set");
            assertEq(vaultUnderlying.balanceOf(account), AMOUNT_AFTER_FEE, "Underlying not received");
        }

        /// @notice U:[TH-G-4]: `finalizeRedeem` reverts when redeemer is not owned
        function test_U_TH_G_04_finalizeRedeem_reverts_when_not_owned() public {
            address redeemer = _redeemAs(account, SHARES);

            vm.prank(newAccount);
            vm.expectRevert(ITreehouseRedemptionGateway.RedeemerNotOwnedByAccountException.selector);
            gateway.finalizeRedeem(redeemer);
        }

        /// @notice U:[TH-G-5]: `transferRedeemer` reassigns ownership when allowed
        function test_U_TH_G_05_transferRedeemer_works() public {
            address redeemer = _redeemAs(account, SHARES);
            transferMaster.setTransferAllowed(account);

            vm.prank(account);
            gateway.transferRedeemer(redeemer, newAccount);

            assertEq(gateway.pendingRedeemers(account).length, 0, "Should leave source pending");
            assertEq(gateway.redeemers(account).length, 0, "Should leave source redeemers");
            assertEq(gateway.redeemers(newAccount).length, 1, "Should join destination redeemers");
            assertEq(gateway.pendingRedeemers(newAccount).length, 0, "Should not be pending on destination");
            assertEq(TreehouseRedeemer(redeemer).account(), newAccount, "Account not updated");
        }

        /// @notice U:[TH-G-6]: `transferRedeemer` reverts when transfer is not allowed
        function test_U_TH_G_06_transferRedeemer_reverts_when_not_allowed() public {
            address redeemer = _redeemAs(account, SHARES);

            vm.prank(account);
            vm.expectRevert(ITreehouseRedemptionGateway.RedeemerTransferNotAllowedException.selector);
            gateway.transferRedeemer(redeemer, newAccount);
        }

        /// @notice U:[TH-G-7]: `rescueToken` reverts while the redeemer is still pending
        function test_U_TH_G_07_rescueToken_reverts_when_still_pending() public {
            address redeemer = _redeemAs(account, SHARES);
            ERC20Mock reward = new ERC20Mock("REWARD", "RWD", 18);
            reward.mint(redeemer, 1e18);

            vm.prank(account);
            vm.expectRevert(ITreehouseRedemptionGateway.RedeemerStillPendingException.selector);
            gateway.rescueToken(redeemer, address(reward));
        }

        /// @notice U:[TH-G-8]: `rescueToken` works after the redeemer is finalized (no longer pending)
        function test_U_TH_G_08_rescueToken_works_after_finalize() public {
            address redeemer = _redeemAs(account, SHARES);

            vm.prank(account);
            gateway.finalizeRedeem(redeemer);

            ERC20Mock reward = new ERC20Mock("REWARD", "RWD", 18);
            reward.mint(redeemer, 7e18);

            vm.prank(account);
            gateway.rescueToken(redeemer, address(reward));

            assertEq(reward.balanceOf(account), 7e18, "Reward not rescued to account");
            assertEq(reward.balanceOf(redeemer), 0, "Redeemer still holds reward");
        }

        /// @notice U:[TH-G-9]: `rescueToken` reverts when redeemer is not owned
        function test_U_TH_G_09_rescueToken_reverts_when_not_owned() public {
            address redeemer = _redeemAs(account, SHARES);
            vm.prank(account);
            gateway.finalizeRedeem(redeemer);

            vm.prank(newAccount);
            vm.expectRevert(ITreehouseRedemptionGateway.RedeemerNotOwnedByAccountException.selector);
            gateway.rescueToken(redeemer, address(vaultUnderlying));
        }

        /// @notice U:[TH-G-10]: phantom token `balanceOf` aggregates pending + claimable amounts
        function test_U_TH_G_10_phantom_token_balanceOf() public {
            _redeemAs(account, SHARES);

            TreehouseRedemptionPhantomToken phantomToken = TreehouseRedemptionPhantomToken(gateway.phantomToken());
            assertEq(phantomToken.balanceOf(account), AMOUNT_AFTER_FEE, "Incorrect phantom balance while pending");

            vm.warp(block.timestamp + redemptionV3.waitingPeriod());
            assertEq(phantomToken.balanceOf(account), AMOUNT_AFTER_FEE, "Incorrect phantom balance when claimable");
        }
    }
