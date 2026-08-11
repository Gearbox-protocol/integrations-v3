// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasRedeemer} from "../../../../integrations/midas/MidasRedeemer.sol";
import {RedemptionStatus} from "../../../../integrations/midas/interfaces/external/IMidasRedemptionVault.sol";

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

/// @dev ERC20 whose `transfer` can be made to revert (e.g. paused token)
contract RevertingTransferERC20Mock is ERC20Mock {
    bool public transfersRevert;

    constructor() ERC20Mock("Reverting mToken", "rMTKN", 18) {}

    function setTransfersRevert(bool value) external {
        transfersRevert = value;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (transfersRevert) revert("TRANSFER_REVERTED");
        return super.transfer(to, amount);
    }
}

/// @dev Minimal ERC20-like token whose `transfer` returns no boolean (USDT-style ABI)
contract NoReturnERC20Mock {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external {
        uint256 fromBalance = balanceOf[msg.sender];
        require(fromBalance >= amount, "INSUFFICIENT_BALANCE");
        unchecked {
            balanceOf[msg.sender] = fromBalance - amount;
            balanceOf[to] += amount;
        }
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
        redeemer = new MidasRedeemer(address(vault), tokenOut18, true);
        redeemer.setAccount(account);
    }

    /// @notice U:[MID-R-1]: Constructor and setAccount work as expected
    function test_U_MID_R_01_constructor_and_setAccount_work() public {
        assertEq(redeemer.gateway(), address(this), "Incorrect gateway");
        assertEq(redeemer.midasRedemptionVault(), address(vault), "Incorrect vault");
        assertEq(redeemer.mToken(), mToken, "Incorrect mToken");
        assertEq(redeemer.quoteToken(), tokenOut18, "Incorrect quote token");
        assertEq(redeemer.mTokenDataFeed(), address(dataFeed), "Incorrect data feed");
        assertEq(redeemer.account(), account, "Incorrect account");
        assertFalse(redeemer.alreadyRequested(), "Should not have requested yet");

        MidasRedeemer initialRateRedeemer = new MidasRedeemer(address(vault), tokenOut18, false);
        assertEq(initialRateRedeemer.mTokenDataFeed(), address(0), "Feed should be unset for initial-rate pricing");

        vm.expectRevert(MidasRedeemer.CallerNotGatewayException.selector);
        vm.prank(makeAddr("NOT_GATEWAY"));
        redeemer.setAccount(makeAddr("NEW_ACCOUNT"));
    }

    /// @notice U:[MID-R-2]: `requestRedeem` works as expected
    function test_U_MID_R_02_requestRedeem_works() public {
        uint256 leftover = 3e18;
        deal(mToken, address(redeemer), leftover);

        redeemer.requestRedeem(100e18);

        assertEq(redeemer.requestId(), 1, "Incorrect requestId");
        assertTrue(redeemer.alreadyRequested(), "Should be marked as requested");
        assertEq(IERC20(mToken).allowance(address(redeemer), address(vault)), 100e18, "Vault not approved");
        assertEq(redeemer.redemptionStartTimestamp(), block.timestamp, "Incorrect start timestamp");
        assertEq(IERC20(mToken).balanceOf(account), leftover, "Leftover mToken should be swept to account");
        assertEq(IERC20(mToken).balanceOf(address(redeemer)), 0, "Redeemer should not retain mToken");
    }

    /// @notice U:[MID-R-3]: `requestRedeem` reverts if already requested
    function test_U_MID_R_03_requestRedeem_reverts_if_already_requested() public {
        redeemer.requestRedeem(100e18);

        vm.expectRevert(MidasRedeemer.AlreadyRequestedException.selector);
        redeemer.requestRedeem(1e18);
    }

    /// @notice U:[MID-R-4]: Gateway-only functions revert on wrong caller
    function test_U_MID_R_04_gateway_only_functions_revert_on_wrong_caller() public {
        vm.startPrank(makeAddr("NOT_GATEWAY"));

        vm.expectRevert(MidasRedeemer.CallerNotGatewayException.selector);
        redeemer.requestRedeem(1e18);

        vm.expectRevert(MidasRedeemer.CallerNotGatewayException.selector);
        redeemer.withdraw(1e18);

        vm.expectRevert(MidasRedeemer.CallerNotGatewayException.selector);
        redeemer.setAccount(makeAddr("NEW_ACCOUNT"));

        vm.stopPrank();
    }

    /// @notice U:[MID-R-5]: `pendingTokenOutAmount` uses the live feed rate when configured
    function test_U_MID_R_05_pendingTokenOutAmount_works_18_decimals() public {
        redeemer.requestRedeem(100e18);

        // mToken rate from data feed = 2.0, tokenOut rate from request = 1.0
        dataFeed.setRate(2e18);
        vault.setRates(1, 1e18, 1e18);

        // 100e18 * 2e18 / 1e18 = 200e18
        assertEq(redeemer.pendingTokenOutAmount(), 200e18, "Incorrect pending amount");
    }

    /// @notice U:[MID-R-6]: `pendingTokenOutAmount` converts to output token decimals (6-decimal output)
    function test_U_MID_R_06_pendingTokenOutAmount_works_6_decimals() public {
        MidasRedeemer redeemer6 = new MidasRedeemer(address(vault), tokenOut6, true);
        redeemer6.setAccount(account);
        redeemer6.requestRedeem(100e18);

        dataFeed.setRate(2e18);
        vault.setRates(1, 1e18, 1e18);

        // 100e18 * 2e18 / 1e18 = 200e18, scaled to 6 decimals => 200e6
        assertEq(redeemer6.pendingTokenOutAmount(), 200e6, "Incorrect pending amount");
    }

    /// @notice U:[MID-R-7]: `pendingTokenOutAmount` returns 0 when request is not pending
    function test_U_MID_R_07_pendingTokenOutAmount_returns_zero() public {
        redeemer.requestRedeem(100e18);

        vault.setStatus(1, uint8(RedemptionStatus.APPROVED));
        assertEq(redeemer.pendingTokenOutAmount(), 0, "Should be 0 for approved request");

        vault.setStatus(1, uint8(RedemptionStatus.REJECTED));
        assertEq(redeemer.pendingTokenOutAmount(), 0, "Should be 0 for rejected request");
    }

    /// @notice U:[MID-R-7A]: `pendingTokenOutAmount` uses the initial request rate when feed is unset
    function test_U_MID_R_07A_pendingTokenOutAmount_uses_initial_rate_when_feed_unset() public {
        MidasRedeemer initialRateRedeemer = new MidasRedeemer(address(vault), tokenOut18, false);
        initialRateRedeemer.setAccount(account);
        initialRateRedeemer.requestRedeem(100e18);

        vault.setRates(1, 1.5e18, 1e18);
        dataFeed.setRate(2e18); // should be ignored because feed is unset

        // 100e18 * 1.5e18 / 1e18 = 150e18
        assertEq(initialRateRedeemer.pendingTokenOutAmount(), 150e18, "Should use initial request rate");
    }

    /// @notice U:[MID-R-8]: `claimableTokenOutAmount` returns the redeemer's token balance
    function test_U_MID_R_08_claimableTokenOutAmount_works() public {
        assertEq(redeemer.claimableTokenOutAmount(), 0, "Should start at 0");

        deal(tokenOut18, address(redeemer), 123e18);
        assertEq(redeemer.claimableTokenOutAmount(), 123e18, "Incorrect claimable amount");
    }

    /// @notice U:[MID-R-9]: `withdraw` transfers quote token and sweeps stranded mToken
    function test_U_MID_R_09_withdraw_works() public {
        redeemer.requestRedeem(100e18);
        deal(tokenOut18, address(redeemer), 100e18);
        deal(mToken, address(redeemer), 5e18);

        redeemer.withdraw(40e18);

        assertEq(IERC20(tokenOut18).balanceOf(account), 40e18, "Account did not receive tokens");
        assertEq(IERC20(tokenOut18).balanceOf(address(redeemer)), 60e18, "Incorrect redeemer balance");
        assertEq(IERC20(mToken).balanceOf(account), 5e18, "Account did not receive stranded mToken");
        assertEq(IERC20(mToken).balanceOf(address(redeemer)), 0, "Redeemer should not retain mToken");
    }

    /// @notice U:[MID-R-10]: `withdraw` reverts on insufficient quote balance
    function test_U_MID_R_10_withdraw_reverts_on_insufficient_balance() public {
        redeemer.requestRedeem(100e18);
        deal(tokenOut18, address(redeemer), 10e18);

        vm.expectRevert(MidasRedeemer.InsufficientBalanceException.selector);
        redeemer.withdraw(20e18);
    }

    /// @notice U:[MID-R-11]: `withdraw(0)` sweeps stranded mToken without transferring quote
    function test_U_MID_R_11_withdraw_zero_sweeps_stranded_mToken() public {
        redeemer.requestRedeem(100e18);
        deal(tokenOut18, address(redeemer), 25e18);
        deal(mToken, address(redeemer), 8e18);

        redeemer.withdraw(0);

        assertEq(IERC20(tokenOut18).balanceOf(account), 0, "Quote should not be transferred for zero amount");
        assertEq(IERC20(tokenOut18).balanceOf(address(redeemer)), 25e18, "Quote should remain on redeemer");
        assertEq(IERC20(mToken).balanceOf(account), 8e18, "Account did not receive stranded mToken");
        assertEq(IERC20(mToken).balanceOf(address(redeemer)), 0, "Redeemer should not retain mToken");
    }

    /// @notice U:[MID-R-12]: `withdraw` still succeeds when mToken sweep transfer reverts
    function test_U_MID_R_12_withdraw_succeeds_when_mToken_transfer_reverts() public {
        RevertingTransferERC20Mock revertingMToken = new RevertingTransferERC20Mock();
        MidasRedemptionVaultMock vaultWithRevertingMToken =
            new MidasRedemptionVaultMock(address(revertingMToken), address(dataFeed));
        MidasRedeemer redeemerWithRevertingMToken =
            new MidasRedeemer(address(vaultWithRevertingMToken), tokenOut18, true);
        redeemerWithRevertingMToken.setAccount(account);

        uint256 quoteAmount = 40e18;
        uint256 strandedMToken = 5e18;
        deal(tokenOut18, address(redeemerWithRevertingMToken), quoteAmount);
        deal(address(revertingMToken), address(redeemerWithRevertingMToken), strandedMToken);
        revertingMToken.setTransfersRevert(true);

        redeemerWithRevertingMToken.withdraw(quoteAmount);

        assertEq(IERC20(tokenOut18).balanceOf(account), quoteAmount, "Account did not receive quote token");
        assertEq(IERC20(tokenOut18).balanceOf(address(redeemerWithRevertingMToken)), 0, "Quote should leave redeemer");
        assertEq(
            revertingMToken.balanceOf(address(redeemerWithRevertingMToken)),
            strandedMToken,
            "Stranded mToken should remain when transfer reverts"
        );
        assertEq(revertingMToken.balanceOf(account), 0, "Account should not receive mToken when transfer reverts");
    }

    /// @notice U:[MID-R-13]: `_sweepMToken` works for tokens that do not return a boolean on transfer
    function test_U_MID_R_13_sweepMToken_works_for_no_return_tokens() public {
        NoReturnERC20Mock noReturnMToken = new NoReturnERC20Mock();
        MidasRedemptionVaultMock vaultWithNoReturnMToken =
            new MidasRedemptionVaultMock(address(noReturnMToken), address(dataFeed));
        MidasRedeemer redeemerWithNoReturnMToken = new MidasRedeemer(address(vaultWithNoReturnMToken), tokenOut18, true);
        redeemerWithNoReturnMToken.setAccount(account);

        uint256 strandedMToken = 7e18;
        noReturnMToken.mint(address(redeemerWithNoReturnMToken), strandedMToken);

        redeemerWithNoReturnMToken.withdraw(0);

        assertEq(noReturnMToken.balanceOf(account), strandedMToken, "Account did not receive stranded mToken");
        assertEq(noReturnMToken.balanceOf(address(redeemerWithNoReturnMToken)), 0, "Redeemer should not retain mToken");
    }
}
