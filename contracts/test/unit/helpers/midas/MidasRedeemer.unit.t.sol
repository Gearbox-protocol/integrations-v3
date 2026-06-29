// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasRedeemer} from "../../../../helpers/midas/MidasRedeemer.sol";

contract MidasDataFeedMock {
    uint256 internal _rate;

    constructor(uint256 initialRate) {
        _rate = initialRate;
    }

    function setRate(uint256 newRate) external {
        _rate = newRate;
    }

    function getDataInBase18() external view returns (uint256) {
        return _rate;
    }
}

/// @dev Mock of the Midas redemption vault, exposing just the surface used by the redeemer.
contract MidasRedemptionVaultMock {
    struct Request {
        address sender;
        address tokenOut;
        uint8 status;
        uint256 amountMTokenIn;
        uint256 mTokenRate;
        uint256 tokenOutRate;
    }

    address public immutable mToken;
    address public immutable mTokenDataFeed;

    uint256 public currentRequestId;
    mapping(uint256 => Request) internal _requests;

    constructor(address _mToken, address _mTokenDataFeed) {
        mToken = _mToken;
        mTokenDataFeed = _mTokenDataFeed;
    }

    function redeemRequest(address tokenOut, uint256 amountMTokenIn) external returns (uint256) {
        currentRequestId++;
        _requests[currentRequestId] = Request({
            sender: msg.sender,
            tokenOut: tokenOut,
            status: 0,
            amountMTokenIn: amountMTokenIn,
            mTokenRate: 1e18,
            tokenOutRate: 1e18
        });
        return currentRequestId;
    }

    function setStatus(uint256 requestId, uint8 status) external {
        _requests[requestId].status = status;
    }

    function setRates(uint256 requestId, uint256 mTokenRate, uint256 tokenOutRate) external {
        _requests[requestId].mTokenRate = mTokenRate;
        _requests[requestId].tokenOutRate = tokenOutRate;
    }

    function redeemRequests(uint256 requestId)
        external
        view
        returns (address, address, uint8, uint256, uint256, uint256)
    {
        Request memory r = _requests[requestId];
        return (r.sender, r.tokenOut, r.status, r.amountMTokenIn, r.mTokenRate, r.tokenOutRate);
    }
}

/// @title MidasRedeemer unit test
/// @notice U:[MID-R]: Unit tests for MidasRedeemer
contract MidasRedeemerUnitTest is Test {
    MidasRedeemer redeemer;
    MidasRedemptionVaultMock vault;
    MidasDataFeedMock dataFeed;

    address mToken;
    address tokenOut18;
    address tokenOut6;
    address account;

    function setUp() public {
        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        tokenOut18 = address(new ERC20Mock("DAI", "DAI", 18));
        tokenOut6 = address(new ERC20Mock("USDC", "USDC", 6));
        account = makeAddr("ACCOUNT");

        dataFeed = new MidasDataFeedMock(1e18);
        vault = new MidasRedemptionVaultMock(mToken, address(dataFeed));

        // gateway == address(this), since the redeemer records its deployer as the gateway
        redeemer = new MidasRedeemer(address(vault));
        redeemer.setAccount(account);
    }

    /// @notice U:[MID-R-1]: Constructor and setAccount work as expected
    function test_U_MID_R_01_constructor_and_setAccount_work() public {
        assertEq(redeemer.gateway(), address(this), "Incorrect gateway");
        assertEq(redeemer.midasRedemptionVault(), address(vault), "Incorrect vault");
        assertEq(redeemer.mToken(), mToken, "Incorrect mToken");
        assertEq(redeemer.mTokenDataFeed(), address(dataFeed), "Incorrect data feed");
        assertEq(redeemer.account(), account, "Incorrect account");
        assertEq(redeemer.redemptionStartTimestamp(), block.timestamp, "Incorrect start timestamp");
        assertFalse(redeemer.alreadyRedeemed(), "Should not be redeemed yet");

        vm.expectRevert(MidasRedeemer.CallerNotGatewayException.selector);
        vm.prank(makeAddr("NOT_GATEWAY"));
        redeemer.setAccount(makeAddr("NEW_ACCOUNT"));
    }

    /// @notice U:[MID-R-2]: `requestRedeem` works as expected
    function test_U_MID_R_02_requestRedeem_works() public {
        redeemer.requestRedeem(tokenOut18, 100e18);

        assertEq(redeemer.requestId(), 1, "Incorrect requestId");
        assertTrue(redeemer.alreadyRedeemed(), "Should be marked as redeemed");
        assertEq(IERC20(mToken).allowance(address(redeemer), address(vault)), 100e18, "Vault not approved");
    }

    /// @notice U:[MID-R-3]: `requestRedeem` reverts if already redeemed
    function test_U_MID_R_03_requestRedeem_reverts_if_already_redeemed() public {
        redeemer.requestRedeem(tokenOut18, 100e18);

        vm.expectRevert(MidasRedeemer.AlreadyRedeemedException.selector);
        redeemer.requestRedeem(tokenOut18, 1e18);
    }

    /// @notice U:[MID-R-4]: Gateway-only functions revert on wrong caller
    function test_U_MID_R_04_gateway_only_functions_revert_on_wrong_caller() public {
        vm.startPrank(makeAddr("NOT_GATEWAY"));

        vm.expectRevert(MidasRedeemer.CallerNotGatewayException.selector);
        redeemer.requestRedeem(tokenOut18, 1e18);

        vm.expectRevert(MidasRedeemer.CallerNotGatewayException.selector);
        redeemer.withdraw(tokenOut18, 1e18);

        vm.expectRevert(MidasRedeemer.CallerNotGatewayException.selector);
        redeemer.setAccount(makeAddr("NEW_ACCOUNT"));

        vm.stopPrank();
    }

    /// @notice U:[MID-R-5]: `pendingTokenOutAmount` computes expected amount (18-decimal output)
    function test_U_MID_R_05_pendingTokenOutAmount_works_18_decimals() public {
        redeemer.requestRedeem(tokenOut18, 100e18);

        // mToken rate from data feed = 2.0, tokenOut rate from request = 1.0
        dataFeed.setRate(2e18);
        vault.setRates(1, 1e18, 1e18);

        // 100e18 * 2e18 / 1e18 = 200e18
        assertEq(redeemer.pendingTokenOutAmount(tokenOut18), 200e18, "Incorrect pending amount");
    }

    /// @notice U:[MID-R-6]: `pendingTokenOutAmount` converts to output token decimals (6-decimal output)
    function test_U_MID_R_06_pendingTokenOutAmount_works_6_decimals() public {
        redeemer.requestRedeem(tokenOut6, 100e18);

        dataFeed.setRate(2e18);
        vault.setRates(1, 1e18, 1e18);

        // 100e18 * 2e18 / 1e18 = 200e18, scaled to 6 decimals => 200e6
        assertEq(redeemer.pendingTokenOutAmount(tokenOut6), 200e6, "Incorrect pending amount");
    }

    /// @notice U:[MID-R-7]: `pendingTokenOutAmount` returns 0 for non-matching conditions
    function test_U_MID_R_07_pendingTokenOutAmount_returns_zero() public {
        redeemer.requestRedeem(tokenOut18, 100e18);

        // tokenOut mismatch
        assertEq(redeemer.pendingTokenOutAmount(tokenOut6), 0, "Should be 0 for non-matching token");

        // status == 1 (processed)
        vault.setStatus(1, 1);
        assertEq(redeemer.pendingTokenOutAmount(tokenOut18), 0, "Should be 0 for processed request");
    }

    /// @notice U:[MID-R-8]: `claimableTokenOutAmount` returns the redeemer's token balance
    function test_U_MID_R_08_claimableTokenOutAmount_works() public {
        assertEq(redeemer.claimableTokenOutAmount(tokenOut18), 0, "Should start at 0");

        deal(tokenOut18, address(redeemer), 123e18);
        assertEq(redeemer.claimableTokenOutAmount(tokenOut18), 123e18, "Incorrect claimable amount");
    }

    /// @notice U:[MID-R-9]: `withdraw` transfers tokens to account
    function test_U_MID_R_09_withdraw_works() public {
        deal(tokenOut18, address(redeemer), 100e18);

        redeemer.withdraw(tokenOut18, 40e18);

        assertEq(IERC20(tokenOut18).balanceOf(account), 40e18, "Account did not receive tokens");
        assertEq(IERC20(tokenOut18).balanceOf(address(redeemer)), 60e18, "Incorrect redeemer balance");
    }

    /// @notice U:[MID-R-10]: `withdraw` reverts on insufficient balance
    function test_U_MID_R_10_withdraw_reverts_on_insufficient_balance() public {
        deal(tokenOut18, address(redeemer), 10e18);

        vm.expectRevert(MidasRedeemer.InsufficientBalanceException.selector);
        redeemer.withdraw(tokenOut18, 20e18);
    }

    /// @notice U:[MID-R-11]: `clearCancelledRequest` works as expected
    function test_U_MID_R_11_clearCancelledRequest_works() public {
        redeemer.requestRedeem(tokenOut18, 100e18);

        // status == 2 (cancelled), rates 1.0 => minAmount == 100e18
        vault.setStatus(1, 2);
        vault.setRates(1, 1e18, 1e18);

        deal(tokenOut18, address(this), 100e18);
        IERC20(tokenOut18).approve(address(redeemer), 100e18);

        redeemer.clearCancelledRequest(100e18);

        assertTrue(redeemer.isManuallyCleared(), "Should be manually cleared");
        assertEq(IERC20(tokenOut18).balanceOf(address(redeemer)), 100e18, "Redeemer did not receive funds");
    }

    /// @notice U:[MID-R-12]: `clearCancelledRequest` reverts when request is not cancelled
    function test_U_MID_R_12_clearCancelledRequest_reverts_when_not_cancelled() public {
        redeemer.requestRedeem(tokenOut18, 100e18);

        // status stays 0 (not cancelled)
        vm.expectRevert(MidasRedeemer.RequestNotCancelledOrManuallyClearedException.selector);
        redeemer.clearCancelledRequest(100e18);
    }

    /// @notice U:[MID-R-13]: `clearCancelledRequest` reverts when supplied amount is too low
    function test_U_MID_R_13_clearCancelledRequest_reverts_when_amount_too_low() public {
        redeemer.requestRedeem(tokenOut18, 100e18);
        vault.setStatus(1, 2);
        vault.setRates(1, 1e18, 1e18);

        vm.expectRevert(MidasRedeemer.AmountIsLessThanRequiredException.selector);
        redeemer.clearCancelledRequest(99e18);
    }

    /// @notice U:[MID-R-14]: `clearCancelledRequest` reverts when already manually cleared
    function test_U_MID_R_14_clearCancelledRequest_reverts_when_already_cleared() public {
        redeemer.requestRedeem(tokenOut18, 100e18);
        vault.setStatus(1, 2);
        vault.setRates(1, 1e18, 1e18);

        deal(tokenOut18, address(this), 200e18);
        IERC20(tokenOut18).approve(address(redeemer), 200e18);
        redeemer.clearCancelledRequest(100e18);

        vm.expectRevert(MidasRedeemer.RequestNotCancelledOrManuallyClearedException.selector);
        redeemer.clearCancelledRequest(100e18);
    }
}
