// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasGateway} from "../../../../helpers/midas/MidasGateway.sol";
import {MidasRedeemer} from "../../../../helpers/midas/MidasRedeemer.sol";
import {IMidasGateway} from "../../../../interfaces/midas/IMidasGateway.sol";
import {RedemptionLogger} from "../../../../helpers/RedemptionLogger.sol";
import {IRedemptionLogger} from "../../../../interfaces/IRedemptionLogger.sol";

contract MidasDataFeedMock {
    function getDataInBase18() external pure returns (uint256) {
        return 1e18;
    }
}

/// @dev Minimal issuance vault: pulls input token from the caller (gateway) and sends back a fixed amount of mToken.
contract MidasIssuanceVaultMock {
    address public immutable mToken;
    uint256 public mTokenAmountOut;

    constructor(address _mToken) {
        mToken = _mToken;
    }

    function setMTokenAmountOut(uint256 amount) external {
        mTokenAmountOut = amount;
    }

    function depositInstant(address tokenIn, uint256 amountToken, uint256, bytes32) external {
        uint256 nativeAmount = _fromE18(amountToken, tokenIn);
        IERC20(tokenIn).transferFrom(msg.sender, address(this), nativeAmount);
        IERC20(mToken).transfer(msg.sender, mTokenAmountOut);
    }

    function _fromE18(uint256 amount, address token) internal view returns (uint256) {
        uint256 tokenUnit = 10 ** IERC20Metadata(token).decimals();
        if (tokenUnit == 1e18) return amount;
        return amount * tokenUnit / 1e18;
    }
}

/// @dev Minimal redemption vault used both for instant redemptions and redemption requests.
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
    uint256 public tokenOutAmount;

    uint256 public currentRequestId;
    mapping(uint256 => Request) internal _requests;

    constructor(address _mToken, address _mTokenDataFeed) {
        mToken = _mToken;
        mTokenDataFeed = _mTokenDataFeed;
    }

    function setTokenOutAmount(uint256 amount) external {
        tokenOutAmount = amount;
    }

    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256) external {
        IERC20(mToken).transferFrom(msg.sender, address(this), amountMTokenIn);
        IERC20(tokenOut).transfer(msg.sender, tokenOutAmount);
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

    function redeemRequests(uint256 requestId)
        external
        view
        returns (address, address, uint8, uint256, uint256, uint256)
    {
        Request memory r = _requests[requestId];
        return (r.sender, r.tokenOut, r.status, r.amountMTokenIn, r.mTokenRate, r.tokenOutRate);
    }
}

contract MidasTransferMasterMock {
    bool internal _isTransferAllowed;

    bytes32 public constant contractType = "MOCK::TRANSFER_MASTER";
    uint256 public constant version = 3_11;

    function setTransferAllowed(bool allowed) external {
        _isTransferAllowed = allowed;
    }

    function isTransferAllowed() external view returns (bool) {
        return _isTransferAllowed;
    }
}

/// @dev Mimics a Credit Account: reports the expected contract type and a configurable credit manager,
///      and can approve tokens so the gateway can pull them via `transferFrom`.
contract CreditAccountMock {
    bytes32 public constant contractType = "CREDIT_ACCOUNT";
    uint256 public constant version = 3_10;

    address public immutable creditManager;

    constructor(address _creditManager) {
        creditManager = _creditManager;
    }

    function approveToken(address token, address spender, uint256 amount) external {
        IERC20(token).approve(spender, amount);
    }
}

/// @dev A contract that reports a non-credit-account contract type, used to exercise the eligibility check.
contract NonCreditAccountMock {
    bytes32 public constant contractType = "NOT_CREDIT_ACCOUNT";
}

contract CreditManagerMock {
    mapping(address => address) internal _borrowers;

    function setBorrower(address creditAccount, address borrower) external {
        _borrowers[creditAccount] = borrower;
    }

    function creditAccountInfo(address creditAccount)
        external
        view
        returns (uint256, uint256, uint128, uint128, uint256, uint16, uint64, address borrower)
    {
        borrower = _borrowers[creditAccount];

        return (0, 0, 0, 0, 0, 0, 0, borrower);
    }
}

/// @title MidasGateway unit test
/// @notice U:[MID-G]: Unit tests for MidasGateway
contract MidasGatewayUnitTest is Test {
    MidasGateway gateway;
    MidasIssuanceVaultMock issuanceVault;
    MidasRedemptionVaultMock redemptionVault;
    MidasDataFeedMock dataFeed;
    MidasTransferMasterMock transferMaster;
    CreditManagerMock creditManager;
    CreditAccountMock account;

    address mToken;
    address inputToken;
    address outputToken;
    address borrower;
    address newAccount;

    uint256 constant REDEMPTION_DURATION = 1 days;

    function setUp() public {
        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        inputToken = address(new ERC20Mock("USDC", "USDC", 6));
        outputToken = address(new ERC20Mock("DAI", "DAI", 18));
        borrower = makeAddr("BORROWER");
        newAccount = makeAddr("NEW_ACCOUNT");

        dataFeed = new MidasDataFeedMock();
        issuanceVault = new MidasIssuanceVaultMock(mToken);
        redemptionVault = new MidasRedemptionVaultMock(mToken, address(dataFeed));
        transferMaster = new MidasTransferMasterMock();
        creditManager = new CreditManagerMock();

        gateway = new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            address(0), // access control (none)
            address(transferMaster),
            address(0), // allowed market configurator (none => skip registration check)
            false, // checkBorrowerGreenlist
            REDEMPTION_DURATION,
            address(0) // redemption logger (none)
        );

        account = new CreditAccountMock(address(creditManager));
        creditManager.setBorrower(address(account), borrower);
    }

    /// @notice U:[MID-G-1]: Constructor works as expected
    function test_U_MID_G_01_constructor_works() public view {
        assertEq(gateway.contractType(), "GATEWAY::MIDAS", "Incorrect contract type");
        assertEq(gateway.version(), 3_11, "Incorrect version");
        assertEq(gateway.midasIssuanceVault(), address(issuanceVault), "Incorrect issuance vault");
        assertEq(gateway.midasRedemptionVault(), address(redemptionVault), "Incorrect redemption vault");
        assertEq(gateway.mToken(), mToken, "Incorrect mToken");
        assertEq(gateway.transferMaster(), address(transferMaster), "Incorrect transfer master");
        assertEq(gateway.expectedRedemptionDuration(), REDEMPTION_DURATION, "Incorrect redemption duration");
        assertEq(gateway.redemptionLogger(), address(0), "Incorrect redemption logger");
        assertTrue(gateway.masterRedeemer() != address(0), "Master redeemer not set");
    }

    /// @notice U:[MID-G-2]: Constructor reverts when issuance/redemption mTokens differ
    function test_U_MID_G_02_constructor_reverts_on_incompatible_vaults() public {
        address otherMToken = address(new ERC20Mock("OTHER", "OTHER", 18));
        MidasIssuanceVaultMock badIssuanceVault = new MidasIssuanceVaultMock(otherMToken);

        vm.expectRevert(IMidasGateway.IncompatibleIssuanceAndRedemptionVaultsException.selector);
        new MidasGateway(
            address(badIssuanceVault),
            address(redemptionVault),
            address(0),
            address(transferMaster),
            address(0),
            false,
            REDEMPTION_DURATION,
            address(0)
        );
    }

    /// @notice U:[MID-G-3]: Constructor reverts when greenlist required but no access control set
    function test_U_MID_G_03_constructor_reverts_on_greenlist_without_access_control() public {
        vm.expectRevert(IMidasGateway.AccessControlNotSetException.selector);
        new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            address(0),
            address(transferMaster),
            address(0),
            true, // checkBorrowerGreenlist with no access control
            REDEMPTION_DURATION,
            address(0)
        );
    }

    /// @notice U:[MID-G-4]: `depositInstant` issues mToken to the account
    function test_U_MID_G_04_depositInstant_works() public {
        uint256 amountIn = 1000e6;
        uint256 mTokenOut = 950e18;

        deal(inputToken, address(account), amountIn);
        account.approveToken(inputToken, address(gateway), amountIn);
        deal(mToken, address(issuanceVault), mTokenOut);
        issuanceVault.setMTokenAmountOut(mTokenOut);

        vm.prank(address(account));
        gateway.depositInstant(inputToken, amountIn, 0, bytes32(0));

        assertEq(IERC20(mToken).balanceOf(address(account)), mTokenOut, "Account did not receive mToken");
        assertEq(IERC20(inputToken).balanceOf(address(issuanceVault)), amountIn, "Vault did not receive input token");
        assertEq(IERC20(mToken).balanceOf(address(gateway)), 0, "mToken stuck in gateway");
    }

    /// @notice U:[MID-G-5]: `redeemInstant` redeems mToken for output token
    function test_U_MID_G_05_redeemInstant_works() public {
        uint256 amountMToken = 100e18;
        uint256 tokenOut = 99e18;

        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);
        deal(outputToken, address(redemptionVault), tokenOut);
        redemptionVault.setTokenOutAmount(tokenOut);

        vm.prank(address(account));
        gateway.redeemInstant(outputToken, amountMToken, 0);

        assertEq(IERC20(outputToken).balanceOf(address(account)), tokenOut, "Account did not receive output token");
        assertEq(IERC20(mToken).balanceOf(address(redemptionVault)), amountMToken, "Vault did not receive mToken");
        assertEq(IERC20(outputToken).balanceOf(address(gateway)), 0, "Output token stuck in gateway");
    }

    /// @notice U:[MID-G-6]: Eligibility-gated functions revert for non-credit-account callers
    function test_U_MID_G_06_reverts_for_ineligible_caller() public {
        address notCreditAccount = address(new NonCreditAccountMock());

        vm.prank(notCreditAccount);
        vm.expectRevert(IMidasGateway.CreditAccountNotEligibleException.selector);
        gateway.depositInstant(inputToken, 1, 0, bytes32(0));

        vm.prank(notCreditAccount);
        vm.expectRevert(IMidasGateway.CreditAccountNotEligibleException.selector);
        gateway.redeemInstant(outputToken, 1, 0);

        vm.prank(notCreditAccount);
        vm.expectRevert(IMidasGateway.CreditAccountNotEligibleException.selector);
        gateway.requestRedeem(outputToken, 1, "");
    }

    /// @notice U:[MID-G-7]: Eligibility reverts when borrower is not set
    function test_U_MID_G_07_reverts_when_borrower_not_set() public {
        CreditAccountMock accountNoBorrower = new CreditAccountMock(address(creditManager));

        vm.prank(address(accountNoBorrower));
        vm.expectRevert(IMidasGateway.CreditAccountNotEligibleException.selector);
        gateway.redeemInstant(outputToken, 1, 0);
    }

    /// @notice U:[MID-G-8]: `requestRedeem` creates a redeemer and forwards the request
    function test_U_MID_G_08_requestRedeem_works() public {
        uint256 amountMToken = 100e18;

        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(outputToken, amountMToken, "");

        address[] memory redeemers = gateway.pendingRedeemers(address(account));
        assertEq(redeemers.length, 1, "Redeemer not created");

        address redeemer = redeemers[0];
        assertEq(IERC20(mToken).balanceOf(redeemer), amountMToken, "Redeemer did not receive mToken");
        assertEq(MidasRedeemer(redeemer).account(), address(account), "Redeemer account not set");
        assertEq(MidasRedeemer(redeemer).requestId(), 1, "Request not forwarded to vault");
        assertTrue(MidasRedeemer(redeemer).alreadyRedeemed(), "Redeemer should be marked as redeemed");
    }

    /// @notice U:[MID-G-9]: `withdraw` pulls funds from fulfilled redeemers
    function test_U_MID_G_09_withdraw_works() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(outputToken, amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];

        // Simulate the request being fulfilled: output tokens land on the redeemer and the request is processed.
        deal(outputToken, redeemer, 99e18);
        redemptionVault.setStatus(1, 1);

        vm.prank(address(account));
        gateway.withdraw(outputToken, 99e18);

        assertEq(IERC20(outputToken).balanceOf(address(account)), 99e18, "Account did not receive output token");
        assertEq(gateway.pendingRedeemers(address(account)).length, 0, "Redeemer not removed from pending list");
    }

    /// @notice U:[MID-G-10]: `withdraw` reverts when not enough is available
    function test_U_MID_G_10_withdraw_reverts_on_insufficient_balance() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(outputToken, amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        deal(outputToken, redeemer, 50e18);
        redemptionVault.setStatus(1, 1);

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.InsufficientBalanceException.selector);
        gateway.withdraw(outputToken, 99e18);
    }

    /// @notice U:[MID-G-11]: `transferRedeemer` reassigns ownership when allowed
    function test_U_MID_G_11_transferRedeemer_works() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(outputToken, amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        transferMaster.setTransferAllowed(true);

        vm.prank(address(account));
        gateway.transferRedeemer(redeemer, newAccount);

        assertEq(gateway.pendingRedeemers(address(account)).length, 0, "Redeemer still owned by old account");
        address[] memory newRedeemers = gateway.pendingRedeemers(newAccount);
        assertEq(newRedeemers.length, 1, "Redeemer not transferred to new account");
        assertEq(newRedeemers[0], redeemer, "Incorrect redeemer transferred");
        assertEq(MidasRedeemer(redeemer).account(), newAccount, "Redeemer account not updated");
    }

    /// @notice U:[MID-G-12]: `transferRedeemer` reverts when transfer not allowed
    function test_U_MID_G_12_transferRedeemer_reverts_when_not_allowed() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(outputToken, amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        transferMaster.setTransferAllowed(false);

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.RedeemerTransferNotAllowedException.selector);
        gateway.transferRedeemer(redeemer, newAccount);
    }

    /// @notice U:[MID-G-13]: `transferRedeemer` reverts when redeemer is not owned by caller
    function test_U_MID_G_13_transferRedeemer_reverts_when_not_owned() public {
        transferMaster.setTransferAllowed(true);

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.RedeemerTransferNotAllowedException.selector);
        gateway.transferRedeemer(makeAddr("UNKNOWN_REDEEMER"), newAccount);
    }

    /// @notice U:[MID-G-14]: `requestRedeem` reverts after reaching the max pending redeemers
    function test_U_MID_G_14_requestRedeem_reverts_on_max_pending() public {
        uint256 count = 10;
        deal(mToken, address(account), (count + 1) * 1e18);
        account.approveToken(mToken, address(gateway), (count + 1) * 1e18);

        vm.startPrank(address(account));
        for (uint256 i = 0; i < count; ++i) {
            gateway.requestRedeem(outputToken, 1e18, "");
        }

        vm.expectRevert(IMidasGateway.MaxPendingRedeemersPerAccountException.selector);
        gateway.requestRedeem(outputToken, 1e18, "");
        vm.stopPrank();
    }

    /// @notice U:[MID-G-15]: `requestRedeem` logs redemption when logger is configured
    function test_U_MID_G_15_requestRedeem_logs_when_logger_configured() public {
        RedemptionLogger logger = new RedemptionLogger(address(this));
        MidasGateway gatewayWithLogger = new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            address(0),
            address(transferMaster),
            address(0),
            false,
            REDEMPTION_DURATION,
            address(logger)
        );
        logger.setGatewayAllowed(address(gatewayWithLogger), true);

        uint256 amountMToken = 100e18;
        bytes memory extraData = abi.encode(uint256(42));

        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gatewayWithLogger), amountMToken);

        vm.prank(address(account));
        gatewayWithLogger.requestRedeem(outputToken, amountMToken, extraData);

        address redeemer = gatewayWithLogger.pendingRedeemers(address(account))[0];
        IRedemptionLogger.RedemptionLog memory log = logger.redemptionLogs(redeemer);
        assertEq(log.creditAccount, address(account), "Incorrect logged credit account");
        assertEq(log.redeemer, redeemer, "Incorrect logged redeemer");
        assertEq(log.extraData, extraData, "Incorrect logged extraData");
    }
}
