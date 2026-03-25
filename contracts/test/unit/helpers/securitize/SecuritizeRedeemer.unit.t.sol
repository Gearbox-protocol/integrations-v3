// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {SecuritizeRedeemer} from "../../../../helpers/securitize/SecuritizeRedeemer.sol";
import {ISecuritizeNAVProvider} from "../../../../integrations/securitize/ISecuritizeNAVProvider.sol";

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

/// @title SecuritizeRedeemer unit test
/// @notice U:[SR]: Unit tests for SecuritizeRedeemer
contract SecuritizeRedeemerUnitTest is Test {
    SecuritizeRedeemer redeemer;
    SecuritizeNAVProviderMock navProvider;

    address gateway;
    address dsToken;
    address stableCoinToken;
    address redemptionAccount;
    address account;

    function setUp() public {
        gateway = address(this);
        dsToken = address(new ERC20Mock("DS", "DS", 18));
        stableCoinToken = address(new ERC20Mock("USDC", "USDC", 6));
        redemptionAccount = makeAddr("REDEMPTION_ACCOUNT");
        account = makeAddr("ACCOUNT");
        navProvider = new SecuritizeNAVProviderMock(1e18);

        redeemer = new SecuritizeRedeemer(dsToken, stableCoinToken, redemptionAccount, address(navProvider));
        redeemer.setAccount(account);
    }

    /// @notice U:[SR-1]: Constructor and setAccount work as expected
    function test_U_SR_01_constructor_and_setAccount_work() public {
        assertEq(redeemer.gateway(), gateway);
        assertEq(redeemer.dsToken(), dsToken);
        assertEq(redeemer.stableCoinToken(), stableCoinToken);
        assertEq(redeemer.redemptionAccount(), redemptionAccount);
        assertEq(redeemer.navProvider(), address(navProvider));
        assertEq(redeemer.dsTokenDecimalsMultiplier(), 1e18);
        assertEq(redeemer.stableCoinDecimalsMultiplier(), 1e6);
        assertEq(redeemer.account(), account);

        vm.expectRevert(SecuritizeRedeemer.CallerNotGatewayException.selector);
        vm.prank(makeAddr("NOT_GATEWAY"));
        redeemer.setAccount(makeAddr("NEW_ACCOUNT"));
    }

    /// @notice U:[SR-2]: redeem transfers DS and updates state
    function test_U_SR_02_redeem_works() public {
        navProvider.setRate(2e18);
        deal(dsToken, address(redeemer), 100e18);

        redeemer.redeem(100e18);

        assertEq(IERC20(dsToken).balanceOf(redemptionAccount), 100e18);
        assertEq(redeemer.startingNavRate(), 2e18);
        assertEq(redeemer.pendingDsTokenAmount(), 100e18);
        assertTrue(redeemer.alreadyRedeemed());
    }

    /// @notice U:[SR-3]: redeem reverts if already redeemed
    function test_U_SR_03_redeem_reverts_if_already_redeemed() public {
        deal(dsToken, address(redeemer), 100e18);
        redeemer.redeem(100e18);

        vm.expectRevert(SecuritizeRedeemer.AlreadyRedeemedException.selector);
        redeemer.redeem(1e18);
    }

    /// @notice U:[SR-4]: claim transfers stablecoin and clears pending amount
    function test_U_SR_04_claim_works() public {
        deal(stableCoinToken, address(redeemer), 250e6);
        deal(dsToken, address(redeemer), 1e18);
        redeemer.redeem(1e18);

        redeemer.claim();

        assertEq(IERC20(stableCoinToken).balanceOf(account), 250e6);
        assertEq(IERC20(stableCoinToken).balanceOf(address(redeemer)), 0);
        assertEq(redeemer.pendingDsTokenAmount(), 0);
    }

    /// @notice U:[SR-5]: Access control works as expected
    function test_U_SR_05_access_control_works() public {
        address notGateway = makeAddr("NOT_GATEWAY");

        vm.startPrank(notGateway);

        vm.expectRevert(SecuritizeRedeemer.CallerNotGatewayException.selector);
        redeemer.redeem(1e18);

        vm.expectRevert(SecuritizeRedeemer.CallerNotGatewayException.selector);
        redeemer.claim();

        vm.stopPrank();
    }

    /// @notice U:[SR-6]: getCurrentRedemptionValue computes value using current NAV
    function test_U_SR_06_getCurrentRedemptionValue_works() public {
        navProvider.setRate(15e17); // 1.5
        deal(dsToken, address(redeemer), 200e18);
        redeemer.redeem(200e18);

        uint256 value = redeemer.getCurrentRedemptionValue();
        assertEq(value, 300e6);
    }

    /// @notice U:[SR-7]: getRedemptionAmount returns min(starting NAV value, current NAV value)
    function test_U_SR_07_getRedemptionAmount_returns_min_value() public {
        navProvider.setRate(2e18);
        deal(dsToken, address(redeemer), 100e18);
        redeemer.redeem(100e18);

        navProvider.setRate(3e18);
        assertEq(redeemer.getRedemptionAmount(), 200e6);

        navProvider.setRate(15e17);
        assertEq(redeemer.getRedemptionAmount(), 150e6);
    }
}
