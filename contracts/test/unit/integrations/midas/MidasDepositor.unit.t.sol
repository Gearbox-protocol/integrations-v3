// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasDepositor} from "../../../../integrations/midas/MidasDepositor.sol";
import {DepositStatus} from "../../../../integrations/midas/interfaces/external/IMidasDepositVault.sol";

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

/// @dev Mock of the Midas deposit vault, exposing just the surface used by the depositor.
contract MidasDepositVaultMock {
    struct Request {
        address recipient;
        address tokenIn;
        uint8 status;
        uint256 depositedUsdAmount;
        uint256 usdAmountWithoutFees;
        uint256 tokenOutRate;
        uint256 depositedInstantUsdAmount;
        uint256 approvedTokenOutRate;
        uint256 amountMToken;
    }

    address public immutable mToken;
    address public immutable mTokenDataFeed;

    uint256 public currentRequestId;
    mapping(uint256 => Request) internal _requests;

    uint256 public lastInstantShare;
    uint256 public lastMinReceive;
    address public lastRecipientRequest;
    address public lastRecipientInstant;

    constructor(address _mToken, address _mTokenDataFeed) {
        mToken = _mToken;
        mTokenDataFeed = _mTokenDataFeed;
    }

    function depositRequest(address tokenIn, uint256 amountToken, bytes32) external returns (uint256) {
        currentRequestId++;
        _requests[currentRequestId] = Request({
            recipient: msg.sender,
            tokenIn: tokenIn,
            status: 0,
            depositedUsdAmount: amountToken,
            usdAmountWithoutFees: amountToken,
            tokenOutRate: 1e18,
            depositedInstantUsdAmount: 0,
            approvedTokenOutRate: 0,
            amountMToken: 0
        });
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountToken);
        return currentRequestId;
    }

    function depositRequest(
        address tokenIn,
        uint256 amountToken,
        bytes32,
        address recipientRequest,
        uint256 instantShare,
        uint256 minReceiveAmountInstantShare,
        address recipientInstant
    ) external returns (uint256, uint256) {
        lastRecipientRequest = recipientRequest;
        lastRecipientInstant = recipientInstant;
        lastInstantShare = instantShare;
        lastMinReceive = minReceiveAmountInstantShare;

        uint256 instantAmount = (amountToken * instantShare) / 10_000;
        uint256 requestAmount = amountToken - instantAmount;

        if (instantAmount > 0) {
            IERC20(mToken).transfer(recipientInstant, instantAmount);
        }

        currentRequestId++;
        _requests[currentRequestId] = Request({
            recipient: recipientRequest,
            tokenIn: tokenIn,
            status: 0,
            depositedUsdAmount: requestAmount,
            usdAmountWithoutFees: requestAmount,
            tokenOutRate: 1e18,
            depositedInstantUsdAmount: instantAmount,
            approvedTokenOutRate: 0,
            amountMToken: 0
        });
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountToken);
        return (currentRequestId, instantAmount);
    }

    function setStatus(uint256 requestId, uint8 status) external {
        _requests[requestId].status = status;
    }

    function setRates(uint256 requestId, uint256 usdAmountWithoutFees, uint256 tokenOutRate) external {
        _requests[requestId].usdAmountWithoutFees = usdAmountWithoutFees;
        _requests[requestId].tokenOutRate = tokenOutRate;
    }

    function mintRequests(uint256 requestId)
        external
        view
        returns (address, address, uint8, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        Request memory r = _requests[requestId];
        return (
            r.recipient,
            r.tokenIn,
            r.status,
            r.depositedUsdAmount,
            r.usdAmountWithoutFees,
            r.tokenOutRate,
            r.depositedInstantUsdAmount,
            r.approvedTokenOutRate,
            r.amountMToken
        );
    }
}

/// @title MidasDepositor unit test
/// @notice U:[MID-D]: Unit tests for MidasDepositor
contract MidasDepositorUnitTest is Test {
    MidasDepositor depositor;
    MidasDepositVaultMock vault;
    MidasDataFeedMock dataFeed;

    address mToken;
    address tokenIn;
    address account;
    bytes32 constant REFERRER_ID = keccak256("GEARBOX");

    function setUp() public {
        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        tokenIn = address(new ERC20Mock("USDC", "USDC", 18));
        account = makeAddr("ACCOUNT");

        dataFeed = new MidasDataFeedMock(1e18);
        vault = new MidasDepositVaultMock(mToken, address(dataFeed));

        depositor = new MidasDepositor(address(vault), tokenIn, REFERRER_ID, true);
        depositor.setAccount(account);
    }

    /// @notice U:[MID-D-1]: Constructor and setAccount work as expected
    function test_U_MID_D_01_constructor_and_setAccount_work() public {
        assertEq(depositor.gateway(), address(this), "Incorrect gateway");
        assertEq(depositor.midasDepositVault(), address(vault), "Incorrect vault");
        assertEq(depositor.mToken(), mToken, "Incorrect mToken");
        assertEq(depositor.tokenIn(), tokenIn, "Incorrect tokenIn");
        assertEq(depositor.referrerId(), REFERRER_ID, "Incorrect referrerId");
        assertEq(depositor.mTokenDataFeed(), address(dataFeed), "Incorrect data feed");
        assertEq(depositor.account(), account, "Incorrect account");
        assertFalse(depositor.alreadyRequested(), "Should not have requested yet");

        MidasDepositor initialRateDepositor = new MidasDepositor(address(vault), tokenIn, REFERRER_ID, false);
        assertEq(initialRateDepositor.mTokenDataFeed(), address(0), "Feed should be unset for initial-rate pricing");

        vm.expectRevert(MidasDepositor.CallerNotGatewayException.selector);
        vm.prank(makeAddr("NOT_GATEWAY"));
        depositor.setAccount(makeAddr("NEW_ACCOUNT"));
    }

    /// @notice U:[MID-D-2]: `requestDeposit` works as expected
    function test_U_MID_D_02_requestDeposit_works() public {
        deal(tokenIn, address(depositor), 100e18);

        depositor.requestDeposit(100e18);

        assertEq(depositor.requestId(), 1, "Incorrect requestId");
        assertTrue(depositor.alreadyRequested(), "Should be marked as requested");
        assertEq(depositor.depositStartTimestamp(), block.timestamp, "Incorrect start timestamp");
        assertEq(IERC20(tokenIn).balanceOf(address(vault)), 100e18, "Vault did not receive tokenIn");
        assertEq(IERC20(tokenIn).balanceOf(address(depositor)), 0, "Depositor should not retain tokenIn");
    }

    /// @notice U:[MID-D-3]: `requestDeposit` reverts if already requested
    function test_U_MID_D_03_requestDeposit_reverts_if_already_requested() public {
        deal(tokenIn, address(depositor), 101e18);
        depositor.requestDeposit(100e18);

        vm.expectRevert(MidasDepositor.AlreadyRequestedException.selector);
        depositor.requestDeposit(1e18);
    }

    /// @notice U:[MID-D-4]: Hybrid deposit mints instant share to account and tracks request on depositor
    function test_U_MID_D_04_requestDepositHybrid_works() public {
        deal(tokenIn, address(depositor), 100e18);
        deal(mToken, address(vault), 100e18);

        depositor.requestDepositHybrid(100e18, 2_500, 20e18);

        assertEq(depositor.requestId(), 1, "Incorrect requestId");
        assertEq(vault.lastRecipientRequest(), address(depositor), "Request recipient should be depositor");
        assertEq(vault.lastRecipientInstant(), account, "Instant recipient should be account");
        assertEq(vault.lastInstantShare(), 2_500, "Incorrect instant share");
        assertEq(IERC20(mToken).balanceOf(account), 25e18, "Account should receive instant mToken");
    }

    /// @notice U:[MID-D-5]: `pendingTokenOutAmount` uses the live feed rate when configured
    function test_U_MID_D_05_pendingTokenOutAmount_works() public {
        deal(tokenIn, address(depositor), 100e18);
        depositor.requestDeposit(100e18);

        dataFeed.setRate(2e18);
        vault.setRates(1, 100e18, 1e18);

        // 100e18 * 1e18 / 2e18 = 50e18
        assertEq(depositor.pendingTokenOutAmount(), 50e18, "Incorrect pending amount");
    }

    /// @notice U:[MID-D-6]: `pendingTokenOutAmount` returns 0 when request is not pending
    function test_U_MID_D_06_pendingTokenOutAmount_returns_zero() public {
        deal(tokenIn, address(depositor), 100e18);
        depositor.requestDeposit(100e18);

        vault.setStatus(1, uint8(DepositStatus.APPROVED));
        assertEq(depositor.pendingTokenOutAmount(), 0, "Should be 0 for approved request");

        vault.setStatus(1, uint8(DepositStatus.REJECTED));
        assertEq(depositor.pendingTokenOutAmount(), 0, "Should be 0 for rejected request");
    }

    /// @notice U:[MID-D-7]: `pendingTokenOutAmount` uses the initial request rate when feed is unset
    function test_U_MID_D_07_pendingTokenOutAmount_uses_initial_rate_when_feed_unset() public {
        MidasDepositor initialRateDepositor = new MidasDepositor(address(vault), tokenIn, REFERRER_ID, false);
        initialRateDepositor.setAccount(account);
        deal(tokenIn, address(initialRateDepositor), 100e18);
        initialRateDepositor.requestDeposit(100e18);

        vault.setRates(1, 150e18, 1.5e18);
        dataFeed.setRate(2e18); // ignored

        // 150e18 * 1e18 / 1.5e18 = 100e18
        assertEq(initialRateDepositor.pendingTokenOutAmount(), 100e18, "Should use initial request rate");
    }

    /// @notice U:[MID-D-8]: `claimableTokenOutAmount` returns the depositor's mToken balance
    function test_U_MID_D_08_claimableTokenOutAmount_works() public {
        assertEq(depositor.claimableTokenOutAmount(), 0, "Should start at 0");

        deal(mToken, address(depositor), 123e18);
        assertEq(depositor.claimableTokenOutAmount(), 123e18, "Incorrect claimable amount");
    }

    /// @notice U:[MID-D-9]: `withdraw` transfers mToken and sweeps stranded tokenIn
    function test_U_MID_D_09_withdraw_works() public {
        deal(tokenIn, address(depositor), 100e18);
        depositor.requestDeposit(100e18);
        deal(mToken, address(depositor), 100e18);
        deal(tokenIn, address(depositor), 5e18);

        depositor.withdraw(40e18);

        assertEq(IERC20(mToken).balanceOf(account), 40e18, "Account did not receive mToken");
        assertEq(IERC20(mToken).balanceOf(address(depositor)), 60e18, "Incorrect depositor mToken balance");
        assertEq(IERC20(tokenIn).balanceOf(account), 5e18, "Account did not receive stranded tokenIn");
        assertEq(IERC20(tokenIn).balanceOf(address(depositor)), 0, "Depositor should not retain tokenIn");
    }

    /// @notice U:[MID-D-10]: `withdraw` reverts on insufficient mToken balance
    function test_U_MID_D_10_withdraw_reverts_on_insufficient_balance() public {
        deal(mToken, address(depositor), 10e18);

        vm.expectRevert(MidasDepositor.InsufficientBalanceException.selector);
        depositor.withdraw(20e18);
    }
}
