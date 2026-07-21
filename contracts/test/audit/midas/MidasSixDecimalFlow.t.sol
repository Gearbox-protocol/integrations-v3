// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasGateway} from "../../../helpers/midas/MidasGateway.sol";
import {MidasRedeemer} from "../../../helpers/midas/MidasRedeemer.sol";

import "./MidasAuditTestBase.sol";

/// @title Midas six-decimal end-to-end flow test
/// @notice E:[MID-6D]: End-to-end issuance, instant redemption, delayed redemption, and
///         withdrawal with a 6-decimal quote token (USDC-like). Covers MID-R16 / tst_core_midas_011.
contract MidasSixDecimalFlowTest is MidasAuditTestBase {
    address internal quoteToken6;
    function setUp() public {
        // Deploy with a 6-decimal quote token instead of the default 18-decimal one.
        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        quoteToken6 = address(new ERC20Mock("USD Coin", "USDC", 6));
        borrower = makeAddr("BORROWER");

        dataFeed = new AuditMidasDataFeed(1e18);
        issuanceVault = new AuditMidasIssuanceVault(mToken);
        redemptionVault = new AuditMidasRedemptionVault(mToken, address(dataFeed));
        creditManager = new AuditCreditManager();
        addressProvider = new AuditAddressProvider(address(0));

        gateway = new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            quoteToken6,
            false, // isAccessControlled
            address(0), // allowed market configurator
            false, // checkBorrowerGreenlist
            1 days,
            true, // withDelayedWithdrawals
            address(addressProvider) // address provider
        );

        liquidator = MidasLiquidator(payable(gateway.transferMaster()));
        phantomToken = MidasRedemptionVaultPhantomToken(gateway.phantomToken());

        account = new AuditCreditAccount(address(creditManager));
        creditManager.setBorrower(address(account), borrower);
    }

    /*
     * @test-id: tst_core_midas_011
     * @scenario: scn_midas_decimals_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::depositInstant
     *          contracts/helpers/midas/MidasGateway.sol::redeemInstant
     *          contracts/helpers/midas/MidasGateway.sol::requestRedeem
     *          contracts/helpers/midas/MidasGateway.sol::withdraw
     *          contracts/helpers/midas/MidasRedeemer.sol::pendingTokenOutAmount
     *          contracts/helpers/midas/MidasRedemptionVaultPhantomToken.sol::balanceOf
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: MidasGateway with a 6-decimal USDC-like quote token
     * Clients: direct calls
     * Mocks: AuditMidasIssuanceVault, AuditMidasRedemptionVault, AuditMidasDataFeed
     * Data: 1000e6 USDC issuance, 1:1 mToken output, instant and delayed redemption
     *
     * Invariant: the full round-trip (issue -> instant redeem, and issue -> delayed redeem
     *            -> withdraw) preserves funds with no decimal-conversion loss for a 6-decimal
     *            quote token, because _convertToE18 is an exact integer multiplication for d<=18.
     */
    function test_tst_core_midas_011_six_decimal_round_trip_preserves_funds() public {
        // --- Issuance: 1000e6 USDC -> 1000e18 mToken (1:1 rate) ---
        uint256 usdcIn = 1000e6;
        uint256 mTokenOut = 1000e18;
        deal(quoteToken6, address(account), usdcIn);
        vm.prank(address(account));
        account.approveToken(quoteToken6, address(gateway), usdcIn);
        deal(mToken, address(issuanceVault), mTokenOut);
        issuanceVault.setMTokenAmountOut(mTokenOut);

        vm.prank(address(account));
        gateway.depositInstant(usdcIn, 0, bytes32(0));

        assertEq(IERC20(mToken).balanceOf(address(account)), mTokenOut, "account received mToken");
        assertEq(IERC20(quoteToken6).balanceOf(address(account)), 0, "account spent all USDC");
        assertEq(IERC20(quoteToken6).balanceOf(address(gateway)), 0, "no USDC dust in gateway");

        // --- Instant redemption: 500e18 mToken -> 500e6 USDC ---
        uint256 mTokenRedeem = 500e18;
        uint256 usdcOut = 500e6;
        deal(quoteToken6, address(redemptionVault), usdcOut);
        redemptionVault.setTokenOutAmount(usdcOut);

        vm.prank(address(account));
        account.approveToken(mToken, address(gateway), mTokenRedeem);
        vm.prank(address(account));
        gateway.redeemInstant(mTokenRedeem, 0);

        assertEq(IERC20(quoteToken6).balanceOf(address(account)), usdcOut, "account received USDC");
        assertEq(IERC20(mToken).balanceOf(address(account)), 500e18, "account has remaining mToken");
        assertEq(IERC20(mToken).balanceOf(address(gateway)), 0, "no mToken dust in gateway");

        // --- Delayed redemption: 500e18 mToken -> request -> fulfill -> withdraw 500e6 USDC ---
        uint256 mTokenRequest = 500e18;
        uint256 vaultMTokenBefore = IERC20(mToken).balanceOf(address(redemptionVault));
        vm.prank(address(account));
        account.approveToken(mToken, address(gateway), mTokenRequest);
        vm.prank(address(account));
        gateway.requestRedeem(mTokenRequest, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        assertEq(IERC20(mToken).balanceOf(redeemer), 0, "mToken pulled from redeemer to vault");
        assertEq(
            IERC20(mToken).balanceOf(address(redemptionVault)) - vaultMTokenBefore,
            mTokenRequest,
            "vault received the requested mToken"
        );

        // Phantom balance: pending = 500e18 * 1e18 / 1e18 = 500e18 (base-18), then converted to
        // 6 decimals: 500e18 * 1e6 / 1e18 = 500e6 USDC. So phantom tracks the 6d value correctly.
        assertEq(phantomToken.balanceOf(address(account)), 500e6, "phantom reports 6d pending value");

        // Fulfill the request: status=1, place 500e6 USDC on the redeemer.
        redemptionVault.setStatus(0, 1);
        deal(quoteToken6, redeemer, usdcOut);

        // After fulfillment, pending=0 (status=1), claimable=500e6. Phantom = 500e6.
        assertEq(phantomToken.balanceOf(address(account)), 500e6, "phantom reports claimable 6d value");

        // Withdraw 500e6 USDC to the account.
        vm.prank(address(account));
        gateway.withdraw(usdcOut);

        assertEq(IERC20(quoteToken6).balanceOf(address(account)), 1000e6, "account has all USDC back");
        assertEq(phantomToken.balanceOf(address(account)), 0, "phantom zeroed after withdrawal");
        assertEq(gateway.pendingRedeemers(address(account)).length, 0, "redeemer removed from pending");
    }

    /*
     * @test-id: tst_core_midas_013
     * @scenario: scn_midas_decimals_002
     * @covers: contracts/helpers/midas/MidasRedeemer.sol::_calculateTokenOutAmount
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: MidasGateway with a 6-decimal quote token and appreciating mToken rate
     * Clients: direct calls
     * Mocks: AuditMidasRedemptionVault, AuditMidasDataFeed
     * Data: 100e18 mToken request, mToken rate 1.5x, 6-decimal output
     *
     * Invariant: pendingTokenOutAmount converts the base-18 expected amount to 6 decimals
     *            with < 1 USDC unit of error. 100e18 mToken * 1.5e18 / 1e18 = 150e18 (base-18),
     *            then 150e18 * 1e6 / 1e18 = 150e6 USDC (exact).
     */
    function test_tst_core_midas_013_six_decimal_pending_amount_with_rate_change() public {
        uint256 mTokenRequest = 100e18;
        vm.prank(address(account));
        account.approveToken(mToken, address(gateway), mTokenRequest);
        deal(mToken, address(account), mTokenRequest);
        vm.prank(address(account));
        gateway.requestRedeem(mTokenRequest, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];

        // mToken rate appreciates 1.5x; tokenOutRate stays at 1e18.
        dataFeed.setRate(1.5e18);

        // 100e18 * 1.5e18 / 1e18 = 150e18 (base-18); 150e18 * 1e6 / 1e18 = 150e6 USDC (exact).
        assertEq(MidasRedeemer(redeemer).pendingTokenOutAmount(), 150e6, "6d pending amount exact at 1.5x rate");
        assertEq(phantomToken.balanceOf(address(account)), 150e6, "phantom matches redeemer pending");
    }
}
