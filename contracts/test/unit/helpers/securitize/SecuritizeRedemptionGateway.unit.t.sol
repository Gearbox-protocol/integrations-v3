// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {SecuritizeRedemptionGateway} from "../../../../helpers/securitize/SecuritizeRedemptionGateway.sol";
import {SecuritizeRedeemer} from "../../../../helpers/securitize/SecuritizeRedeemer.sol";
import {ISecuritizeNAVProvider} from "../../../../integrations/securitize/ISecuritizeNAVProvider.sol";
import {ISecuritizeWhitelister} from "../../../../integrations/securitize/ISecuritizeWhitelister.sol";
import {ISecuritizeGatewayTransferMaster} from "../../../../interfaces/securitize/ISecuritizeGatewayTransferMaster.sol";
import {ISecuritizeRedemptionGateway} from "../../../../interfaces/securitize/ISecuritizeRedemptionGateway.sol";

contract SecuritizeNAVProviderMock is ISecuritizeNAVProvider {
    uint256 internal _rate;

    constructor(uint256 initialRate) {
        _rate = initialRate;
    }

    function setRate(uint256 newRate) external {
        _rate = newRate;
    }

    function rate() external view returns (uint256) {
        return _rate;
    }
}

contract SecuritizeWhitelisterMock is ISecuritizeWhitelister {
    uint256 public calls;
    address public lastCreditAccount;
    address public lastHelperAccount;
    address public lastToken;

    function registerHelperAccount(address creditAccount, address helperAccount, address token) external {
        calls++;
        lastCreditAccount = creditAccount;
        lastHelperAccount = helperAccount;
        lastToken = token;
    }
}

contract SecuritizeGatewayTransferMasterMock is ISecuritizeGatewayTransferMaster {
    bool internal _isTransferAllowed;

    bytes32 public constant override contractType = "MOCK::TRANSFER_MASTER";
    uint256 public constant override version = 3_10;

    function setTransferAllowed(bool allowed) external {
        _isTransferAllowed = allowed;
    }

    function isTransferAllowed() external view returns (bool) {
        return _isTransferAllowed;
    }
}

/// @title SecuritizeRedemptionGateway unit test
/// @notice U:[SRG]: Unit tests for SecuritizeRedemptionGateway
contract SecuritizeRedemptionGatewayUnitTest is Test {
    SecuritizeRedemptionGateway gateway;
    SecuritizeNAVProviderMock navProvider;
    SecuritizeWhitelisterMock whitelister;
    SecuritizeGatewayTransferMasterMock transferMaster;

    address dsToken;
    address stableCoinToken;
    address redemptionAccount;
    address account;
    address newAccount;

    function setUp() public {
        dsToken = address(new ERC20Mock("DS", "DS", 18));
        stableCoinToken = address(new ERC20Mock("USDC", "USDC", 6));
        redemptionAccount = makeAddr("REDEMPTION_ACCOUNT");
        account = makeAddr("ACCOUNT");
        newAccount = makeAddr("NEW_ACCOUNT");

        navProvider = new SecuritizeNAVProviderMock(1e18);
        whitelister = new SecuritizeWhitelisterMock();
        transferMaster = new SecuritizeGatewayTransferMasterMock();

        gateway = new SecuritizeRedemptionGateway(
            dsToken,
            stableCoinToken,
            redemptionAccount,
            address(whitelister),
            address(transferMaster),
            address(navProvider)
        );
    }

    /// @notice U:[SRG-1]: Constructor works as expected
    function test_U_SRG_01_constructor_works() public {
        assertEq(gateway.contractType(), "GATEWAY::SECURITIZE_REDEMPTION");
        assertEq(gateway.version(), 3_10);
        assertEq(gateway.dsToken(), dsToken);
        assertEq(gateway.stableCoinToken(), stableCoinToken);
        assertEq(gateway.redemptionAccount(), redemptionAccount);
        assertEq(gateway.securitizeWhitelister(), address(whitelister));
        assertEq(gateway.transferMaster(), address(transferMaster));
        assertTrue(gateway.masterRedeemer() != address(0));
    }

    /// @notice U:[SRG-2]: redeem creates a redeemer and executes redemption flow
    function test_U_SRG_02_redeem_works() public {
        navProvider.setRate(2e18);
        deal(dsToken, account, 100e18);

        vm.prank(account);
        IERC20(dsToken).approve(address(gateway), 100e18);

        vm.prank(account);
        gateway.redeem(100e18);

        address[] memory redeemers = gateway.getRedeemers(account);
        assertEq(redeemers.length, 1);

        address redeemer = redeemers[0];
        assertEq(gateway.getUnclaimedRedeemers(account).length, 1);
        assertEq(whitelister.calls(), 1);
        assertEq(whitelister.lastCreditAccount(), account);
        assertEq(whitelister.lastHelperAccount(), redeemer);
        assertEq(whitelister.lastToken(), dsToken);

        assertEq(IERC20(dsToken).balanceOf(redemptionAccount), 100e18);
        assertEq(SecuritizeRedeemer(redeemer).account(), account);
        assertEq(SecuritizeRedeemer(redeemer).pendingDsTokenAmount(), 100e18);
        assertEq(SecuritizeRedeemer(redeemer).startingNavRate(), 2e18);
        assertTrue(SecuritizeRedeemer(redeemer).alreadyRedeemed());
    }

    /// @notice U:[SRG-3]: redeem creates a new redeemer on each call
    function test_U_SRG_03_redeem_creates_new_redeemer_each_time() public {
        deal(dsToken, account, 300e18);

        vm.startPrank(account);
        IERC20(dsToken).approve(address(gateway), 300e18);
        gateway.redeem(100e18);
        gateway.redeem(200e18);
        vm.stopPrank();

        address[] memory redeemers = gateway.getRedeemers(account);
        assertEq(redeemers.length, 2);
        assertTrue(redeemers[0] != redeemers[1]);
        assertEq(gateway.getUnclaimedRedeemers(account).length, 2);
        assertEq(whitelister.calls(), 2);
    }

    /// @notice U:[SRG-4]: claim transfers stablecoin and removes redeemer from unclaimed list
    function test_U_SRG_04_claim_works() public {
        deal(dsToken, account, 100e18);
        vm.prank(account);
        IERC20(dsToken).approve(address(gateway), 100e18);
        vm.prank(account);
        gateway.redeem(100e18);

        address redeemer = gateway.getRedeemers(account)[0];
        deal(stableCoinToken, redeemer, 123e6);

        vm.prank(account);
        gateway.claim(_toArray(redeemer));

        assertEq(IERC20(stableCoinToken).balanceOf(account), 123e6);
        assertEq(gateway.getRedeemers(account).length, 1);
        assertEq(gateway.getUnclaimedRedeemers(account).length, 0);
    }

    /// @notice U:[SRG-5]: claim reverts when redeemer is not owned by account
    function test_U_SRG_05_claim_reverts_if_not_owned() public {
        deal(dsToken, account, 100e18);
        vm.prank(account);
        IERC20(dsToken).approve(address(gateway), 100e18);
        vm.prank(account);
        gateway.redeem(100e18);

        address redeemer = gateway.getRedeemers(account)[0];

        vm.expectRevert(ISecuritizeRedemptionGateway.RedeemerNotOwnedByAccountException.selector);
        vm.prank(newAccount);
        gateway.claim(_toArray(redeemer));
    }

    /// @notice U:[SRG-6]: getRedemptionAmount sums over all unclaimed redeemers
    function test_U_SRG_06_getRedemptionAmount_works() public {
        deal(dsToken, account, 150e18);
        vm.startPrank(account);
        IERC20(dsToken).approve(address(gateway), 150e18);

        navProvider.setRate(1e18);
        gateway.redeem(100e18);

        navProvider.setRate(2e18);
        gateway.redeem(50e18);
        vm.stopPrank();

        navProvider.setRate(1e18);
        assertEq(gateway.getRedemptionAmount(account), 150e6);

        address redeemerToClaim = gateway.getRedeemers(account)[0];
        deal(stableCoinToken, redeemerToClaim, 100e6);
        vm.prank(account);
        gateway.claim(_toArray(redeemerToClaim));

        assertEq(gateway.getRedemptionAmount(account), 50e6);
    }

    /// @notice U:[SRG-7]: transferRedeemer reassigns ownership when transfer is allowed
    function test_U_SRG_07_transferRedeemer_works_when_allowed() public {
        deal(dsToken, account, 100e18);
        vm.prank(account);
        IERC20(dsToken).approve(address(gateway), 100e18);
        vm.prank(account);
        gateway.redeem(100e18);

        address redeemer = gateway.getRedeemers(account)[0];
        transferMaster.setTransferAllowed(true);

        vm.prank(account);
        gateway.transferRedeemer(redeemer, newAccount);

        assertEq(gateway.getRedeemers(account).length, 0);
        assertEq(gateway.getUnclaimedRedeemers(account).length, 0);
        assertEq(gateway.getRedeemers(newAccount).length, 1);
        assertEq(gateway.getUnclaimedRedeemers(newAccount).length, 1);
        assertEq(gateway.getRedeemers(newAccount)[0], redeemer);

        assertEq(whitelister.calls(), 1);
        assertEq(whitelister.lastCreditAccount(), account);
        assertEq(whitelister.lastHelperAccount(), redeemer);
        assertEq(whitelister.lastToken(), dsToken);

        // Ensure claim after transfer goes to `newAccount` (redeemer account is updated).
        deal(stableCoinToken, redeemer, 123e6);
        vm.prank(newAccount);
        gateway.claim(_toArray(redeemer));
        assertEq(IERC20(stableCoinToken).balanceOf(newAccount), 123e6);
    }

    /// @notice U:[SRG-8]: transferRedeemer reverts when transfer is not allowed
    function test_U_SRG_08_transferRedeemer_reverts_when_not_allowed() public {
        deal(dsToken, account, 100e18);
        vm.prank(account);
        IERC20(dsToken).approve(address(gateway), 100e18);
        vm.prank(account);
        gateway.redeem(100e18);

        address redeemer = gateway.getRedeemers(account)[0];
        transferMaster.setTransferAllowed(false);

        vm.expectRevert(ISecuritizeRedemptionGateway.RedeemerTransferNotAllowedException.selector);
        vm.prank(account);
        gateway.transferRedeemer(redeemer, newAccount);
    }

    /// @notice U:[SRG-9]: transferRedeemer reverts when redeemer is not owned
    function test_U_SRG_09_transferRedeemer_reverts_if_not_owned() public {
        vm.expectRevert(ISecuritizeRedemptionGateway.RedeemerNotOwnedByAccountException.selector);
        vm.prank(account);
        gateway.transferRedeemer(makeAddr("UNKNOWN_REDEEMER"), newAccount);
    }

    /// @notice U:[SRG-10]: claim works after transferRedeemer
    function test_U_SRG_10_claim_works_after_transferRedeemer() public {
        deal(dsToken, account, 100e18);
        vm.prank(account);
        IERC20(dsToken).approve(address(gateway), 100e18);

        vm.prank(account);
        gateway.redeem(100e18);

        address redeemer = gateway.getRedeemers(account)[0];
        transferMaster.setTransferAllowed(true);

        vm.prank(account);
        gateway.transferRedeemer(redeemer, newAccount);

        // Simulate stablecoins already received by the redeemer clone.
        deal(stableCoinToken, redeemer, 55e6);

        vm.prank(newAccount);
        gateway.claim(_toArray(redeemer));

        assertEq(IERC20(stableCoinToken).balanceOf(newAccount), 55e6);
        assertEq(gateway.getRedeemers(newAccount).length, 1);
        assertEq(gateway.getUnclaimedRedeemers(newAccount).length, 0);
    }

    function _toArray(address value) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = value;
    }
}
