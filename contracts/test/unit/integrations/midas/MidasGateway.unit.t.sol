// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasGateway} from "../../../../integrations/midas/MidasGateway.sol";
import {MidasRedeemer} from "../../../../integrations/midas/MidasRedeemer.sol";
import {MidasRedemptionVaultPhantomToken} from "../../../../integrations/midas/MidasRedemptionVaultPhantomToken.sol";
import {IMidasGateway} from "../../../../integrations/midas/interfaces/IMidasGateway.sol";
import {RedemptionLogger} from "../../../../integrations/common/RedemptionLogger.sol";
import {
    IRedemptionLogger,
    AP_REDEMPTION_LOGGER
} from "../../../../integrations/common/interfaces/IRedemptionLogger.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IAddressProvider} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAddressProvider.sol";

contract MidasDataFeedMock {
    function getDataInBase18() external pure returns (uint256) {
        return 1e18;
    }
}

/// @dev Minimal issuance vault: pulls input token from the caller (gateway) and sends back a fixed amount of mToken.
contract MidasIssuanceVaultMock {
    address public immutable mToken;
    address public accessControl;
    uint256 public mTokenAmountOut;

    constructor(address _mToken) {
        mToken = _mToken;
    }

    function setMTokenAmountOut(uint256 amount) external {
        mTokenAmountOut = amount;
    }

    function setAccessControl(address accessControl_) external {
        accessControl = accessControl_;
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
    address public accessControl;
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

    function setAccessControl(address accessControl_) external {
        accessControl = accessControl_;
    }

    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256) external {
        IERC20(mToken).transferFrom(msg.sender, address(this), amountMTokenIn);
        IERC20(tokenOut).transfer(msg.sender, tokenOutAmount);
    }

    function redeemRequest(address tokenOut, uint256 amountMTokenIn) external returns (uint256) {
        IERC20(mToken).transferFrom(msg.sender, address(this), amountMTokenIn);
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

contract ContractsRegisterMock {
    mapping(address => bool) internal _isCreditManager;

    function setCreditManager(address creditManager, bool isCreditManager_) external {
        _isCreditManager[creditManager] = isCreditManager_;
    }

    function isCreditManager(address creditManager) external view returns (bool) {
        return _isCreditManager[creditManager];
    }
}

contract MarketConfiguratorMock {
    address public immutable contractsRegister;

    constructor(address contractsRegister_) {
        contractsRegister = contractsRegister_;
    }
}

contract MidasAccessControlMock {
    mapping(bytes32 => mapping(address => bool)) internal _roles;

    function grantRole(bytes32 role, address account) external {
        _roles[role][account] = true;
    }

    function revokeRole(bytes32 role, address account) external {
        _roles[role][account] = false;
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return _roles[role][account];
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

/// @title MidasGateway unit test
/// @notice U:[MID-G]: Unit tests for MidasGateway
contract MidasGatewayUnitTest is Test {
    MidasGateway gateway;
    MidasIssuanceVaultMock issuanceVault;
    MidasRedemptionVaultMock redemptionVault;
    MidasDataFeedMock dataFeed;
    CreditManagerMock creditManager;
    CreditAccountMock account;

    address mToken;
    address quoteToken;
    address borrower;
    address newAccount;
    address transferMaster;
    RedemptionLoggerAddressProviderMock addressProvider;

    uint256 constant REDEMPTION_DURATION = 1 days;

    function setUp() public {
        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        quoteToken = address(new ERC20Mock("DAI", "DAI", 18));
        borrower = makeAddr("BORROWER");
        newAccount = makeAddr("NEW_ACCOUNT");

        dataFeed = new MidasDataFeedMock();
        issuanceVault = new MidasIssuanceVaultMock(mToken);
        redemptionVault = new MidasRedemptionVaultMock(mToken, address(dataFeed));
        creditManager = new CreditManagerMock();
        addressProvider = new RedemptionLoggerAddressProviderMock(address(0));

        gateway = new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            quoteToken,
            false, // isAccessControlled
            address(0), // allowed market configurator (none => skip registration check)
            false, // checkBorrowerGreenlist
            REDEMPTION_DURATION,
            true, // withDelayedWithdrawals
            address(addressProvider)
        );
        transferMaster = gateway.transferMaster();

        account = new CreditAccountMock(address(creditManager));
        creditManager.setBorrower(address(account), borrower);
    }

    function _setTransferAllowedFor(address account_) internal {
        // `MidasLiquidator.transferableRedeemerOwner` is the sole storage variable (slot 0).
        vm.store(transferMaster, bytes32(uint256(0)), bytes32(uint256(uint160(account_))));
    }

    function _clearTransferAllowed() internal {
        vm.store(transferMaster, bytes32(uint256(0)), bytes32(uint256(0)));
    }

    /// @notice U:[MID-G-1]: Constructor works as expected
    function test_U_MID_G_01_constructor_works() public view {
        assertEq(gateway.contractType(), "GATEWAY::MIDAS", "Incorrect contract type");
        assertEq(gateway.version(), 3_11, "Incorrect version");
        assertEq(gateway.midasIssuanceVault(), address(issuanceVault), "Incorrect issuance vault");
        assertEq(gateway.midasRedemptionVault(), address(redemptionVault), "Incorrect redemption vault");
        assertEq(gateway.mToken(), mToken, "Incorrect mToken");
        assertEq(gateway.quoteToken(), quoteToken, "Incorrect quote token");
        assertTrue(gateway.phantomToken() != address(0), "Phantom token not deployed");
        assertEq(
            MidasRedemptionVaultPhantomToken(gateway.phantomToken()).gateway(), address(gateway), "Incorrect PT gateway"
        );
        assertTrue(gateway.transferMaster() != address(0), "Transfer master not deployed");
        assertEq(
            IVersion(gateway.transferMaster()).contractType(), "RWA_LIQUIDATOR::MIDAS", "Incorrect transfer master type"
        );
        assertEq(gateway.expectedRedemptionDuration(), REDEMPTION_DURATION, "Incorrect redemption duration");
        assertEq(gateway.redemptionLogger(), address(0), "Incorrect redemption logger");
        assertTrue(gateway.masterRedeemer() != address(0), "Master redeemer not set");
    }

    /// @notice U:[MID-G-1A]: Phantom token deployed in constructor has correct parameters
    function test_U_MID_G_01A_constructor_deploys_phantom_token_with_correct_params() public view {
        MidasRedemptionVaultPhantomToken phantomToken = MidasRedemptionVaultPhantomToken(gateway.phantomToken());

        assertEq(phantomToken.contractType(), "PHANTOM_TOKEN::MIDAS_REDEMPTION", "Incorrect contract type");
        assertEq(phantomToken.version(), 3_11, "Incorrect version");
        assertEq(phantomToken.gateway(), address(gateway), "Incorrect gateway");
        assertEq(phantomToken.underlying(), quoteToken, "Incorrect underlying");
        assertEq(phantomToken.decimals(), 18, "Incorrect decimals");
        assertEq(phantomToken.name(), "mTBILL redeemed to DAI", "Incorrect name");
        assertEq(phantomToken.symbol(), "mTBILLrdDAI", "Incorrect symbol");

        (address gw, address underlying) = phantomToken.getPhantomTokenInfo();
        assertEq(gw, address(gateway), "Incorrect gateway from getPhantomTokenInfo");
        assertEq(underlying, quoteToken, "Incorrect underlying from getPhantomTokenInfo");

        (address sgw, address sunderlying) = abi.decode(phantomToken.serialize(), (address, address));
        assertEq(sgw, address(gateway), "Incorrect gateway in serialized data");
        assertEq(sunderlying, quoteToken, "Incorrect underlying in serialized data");
    }

    /// @notice U:[MID-G-1B]: Constructor skips phantom token when delayed withdrawals are disabled
    function test_U_MID_G_01B_constructor_skips_phantom_token_without_delayed_withdrawals() public {
        MidasGateway gatewayWithoutPhantomToken = new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            quoteToken,
            false,
            address(0),
            false,
            REDEMPTION_DURATION,
            false, // withDelayedWithdrawals
            address(addressProvider) // address provider
        );

        assertEq(gatewayWithoutPhantomToken.phantomToken(), address(0), "Phantom token should not be deployed");
    }

    /// @notice U:[MID-G-2]: Constructor reverts when issuance/redemption mTokens differ
    function test_U_MID_G_02_constructor_reverts_on_incompatible_vaults() public {
        address otherMToken = address(new ERC20Mock("OTHER", "OTHER", 18));
        MidasIssuanceVaultMock badIssuanceVault = new MidasIssuanceVaultMock(otherMToken);

        vm.expectRevert(IMidasGateway.IncompatibleIssuanceAndRedemptionVaultsException.selector);
        new MidasGateway(
            address(badIssuanceVault),
            address(redemptionVault),
            quoteToken,
            false,
            address(0),
            false,
            REDEMPTION_DURATION,
            true, // withDelayedWithdrawals
            address(addressProvider) // address provider
        );
    }

    /// @notice U:[MID-G-2A]: Constructor reads matching access control from the vaults
    function test_U_MID_G_02A_constructor_reads_matching_access_control() public {
        address accessControl = makeAddr("ACCESS_CONTROL");
        issuanceVault.setAccessControl(accessControl);
        redemptionVault.setAccessControl(accessControl);

        ContractsRegisterMock contractsRegister = new ContractsRegisterMock();
        MarketConfiguratorMock marketConfigurator = new MarketConfiguratorMock(address(contractsRegister));

        MidasGateway controlledGateway = new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            quoteToken,
            true,
            address(marketConfigurator),
            false,
            REDEMPTION_DURATION,
            true, // withDelayedWithdrawals
            address(addressProvider) // address provider
        );

        assertEq(controlledGateway.accessControl(), accessControl, "Incorrect access control");
        assertEq(
            controlledGateway.allowedMarketConfigurator(), address(marketConfigurator), "Incorrect market configurator"
        );
    }

    /// @notice U:[MID-G-2B]: Constructor reverts when vault access controls differ
    function test_U_MID_G_02B_constructor_reverts_on_incompatible_access_controls() public {
        issuanceVault.setAccessControl(makeAddr("ISSUANCE_ACCESS_CONTROL"));
        redemptionVault.setAccessControl(makeAddr("REDEMPTION_ACCESS_CONTROL"));

        vm.expectRevert(IMidasGateway.IncompatibleAccessControlsException.selector);
        new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            quoteToken,
            true,
            address(1),
            false,
            REDEMPTION_DURATION,
            true, // withDelayedWithdrawals
            address(addressProvider) // address provider
        );
    }

    /// @notice U:[MID-G-2C]: Constructor reverts when permissioned mode allows arbitrary accounts
    function test_U_MID_G_02C_constructor_reverts_when_permissioned_without_market_configurator() public {
        address accessControl = makeAddr("ACCESS_CONTROL");
        issuanceVault.setAccessControl(accessControl);
        redemptionVault.setAccessControl(accessControl);

        vm.expectRevert(IMidasGateway.ArbitraryCAAllowedInPermissionedModeException.selector);
        new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            quoteToken,
            true,
            address(0), // no market configurator in permissioned mode
            false,
            REDEMPTION_DURATION,
            true,
            address(addressProvider)
        );
    }

    /// @notice U:[MID-G-3]: Constructor reverts when greenlist required but no access control set
    function test_U_MID_G_03_constructor_reverts_on_greenlist_without_access_control() public {
        vm.expectRevert(IMidasGateway.AccessControlNotSetException.selector);
        new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            quoteToken,
            false, // not access-controlled => accessControl stays zero
            address(0),
            true, // checkBorrowerGreenlist with no access control
            REDEMPTION_DURATION,
            true, // withDelayedWithdrawals
            address(addressProvider) // address provider
        );
    }

    /// @notice U:[MID-G-4]: `depositInstant` issues mToken to the account
    function test_U_MID_G_04_depositInstant_works() public {
        uint256 amountIn = 1000e18;
        uint256 mTokenOut = 950e18;

        deal(quoteToken, address(account), amountIn);
        account.approveToken(quoteToken, address(gateway), amountIn);
        deal(mToken, address(issuanceVault), mTokenOut);
        issuanceVault.setMTokenAmountOut(mTokenOut);

        vm.prank(address(account));
        gateway.depositInstant(amountIn, 0, bytes32(0));

        assertEq(IERC20(mToken).balanceOf(address(account)), mTokenOut, "Account did not receive mToken");
        assertEq(IERC20(quoteToken).balanceOf(address(issuanceVault)), amountIn, "Vault did not receive quote token");
        assertEq(IERC20(mToken).balanceOf(address(gateway)), 0, "mToken stuck in gateway");
    }

    /// @notice U:[MID-G-5]: `redeemInstant` redeems mToken for output token
    function test_U_MID_G_05_redeemInstant_works() public {
        uint256 amountMToken = 100e18;
        uint256 amountQuoteToken = 99e18;

        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);
        deal(quoteToken, address(redemptionVault), amountQuoteToken);
        redemptionVault.setTokenOutAmount(amountQuoteToken);

        vm.prank(address(account));
        gateway.redeemInstant(amountMToken, 0);

        assertEq(
            IERC20(quoteToken).balanceOf(address(account)), amountQuoteToken, "Account did not receive quote token"
        );
        assertEq(IERC20(mToken).balanceOf(address(redemptionVault)), amountMToken, "Vault did not receive mToken");
        assertEq(IERC20(quoteToken).balanceOf(address(gateway)), 0, "Quote token stuck in gateway");
    }

    /// @notice U:[MID-G-6]: Non-access-controlled gateways accept any caller
    function test_U_MID_G_06_allows_any_caller_without_access_control() public {
        address notCreditAccount = address(new NonCreditAccountMock());
        uint256 amountIn = 1000e18;
        uint256 mTokenOut = 950e18;

        deal(quoteToken, notCreditAccount, amountIn);
        vm.prank(notCreditAccount);
        IERC20(quoteToken).approve(address(gateway), amountIn);
        deal(mToken, address(issuanceVault), mTokenOut);
        issuanceVault.setMTokenAmountOut(mTokenOut);

        vm.prank(notCreditAccount);
        gateway.depositInstant(amountIn, 0, bytes32(0));

        assertEq(IERC20(mToken).balanceOf(notCreditAccount), mTokenOut, "Caller did not receive mToken");
    }

    /// @notice U:[MID-G-6A]: Access-controlled gateways revert for non-credit-account callers
    function test_U_MID_G_06A_reverts_for_ineligible_caller_when_access_controlled() public {
        (MidasGateway controlledGateway,) = _deployAccessControlledGateway(false);

        address notCreditAccount = address(new NonCreditAccountMock());

        vm.prank(notCreditAccount);
        vm.expectRevert(IMidasGateway.CreditAccountNotEligibleException.selector);
        controlledGateway.depositInstant(1, 0, bytes32(0));

        vm.prank(notCreditAccount);
        vm.expectRevert(IMidasGateway.CreditAccountNotEligibleException.selector);
        controlledGateway.redeemInstant(1, 0);

        vm.prank(notCreditAccount);
        vm.expectRevert(IMidasGateway.CreditAccountNotEligibleException.selector);
        controlledGateway.requestRedeem(1, "");
    }

    /// @notice U:[MID-G-7]: Access-controlled gateways revert when borrower is not set
    function test_U_MID_G_07_reverts_when_borrower_not_set() public {
        (MidasGateway controlledGateway, ContractsRegisterMock contractsRegister) =
            _deployAccessControlledGateway(false);
        contractsRegister.setCreditManager(address(creditManager), true);

        CreditAccountMock accountNoBorrower = new CreditAccountMock(address(creditManager));

        vm.prank(address(accountNoBorrower));
        vm.expectRevert(IMidasGateway.CreditAccountNotEligibleException.selector);
        controlledGateway.redeemInstant(1, 0);
    }

    /// @notice U:[MID-G-7A]: Access-controlled gateways revert when credit manager is not registered
    function test_U_MID_G_07A_reverts_when_credit_manager_not_registered() public {
        (MidasGateway controlledGateway,) = _deployAccessControlledGateway(false);

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.CreditAccountNotEligibleException.selector);
        controlledGateway.redeemInstant(1, 0);
    }

    /// @notice U:[MID-G-8]: `requestRedeem` creates a redeemer and forwards the request
    function test_U_MID_G_08_requestRedeem_works() public {
        uint256 amountMToken = 100e18;

        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(amountMToken, "");

        address[] memory redeemers = gateway.pendingRedeemers(address(account));
        assertEq(redeemers.length, 1, "Redeemer not created");

        address redeemer = redeemers[0];
        // Remaining mToken is swept back to the account when the vault does not consume the full amount.
        // The mock consumes the full amount, so the redeemer balance is zero after the request.
        assertEq(IERC20(mToken).balanceOf(redeemer), 0, "Redeemer should not retain mToken");
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
        gateway.requestRedeem(amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];

        // Simulate the request being fulfilled: output tokens land on the redeemer and the request is processed.
        deal(quoteToken, redeemer, 99e18);
        redemptionVault.setStatus(1, 1);

        vm.prank(address(account));
        gateway.withdraw(99e18);

        assertEq(IERC20(quoteToken).balanceOf(address(account)), 99e18, "Account did not receive quote token");
        assertEq(gateway.pendingRedeemers(address(account)).length, 0, "Redeemer not removed from pending list");
    }

    /// @notice U:[MID-G-10]: `withdraw` reverts when not enough is available
    function test_U_MID_G_10_withdraw_reverts_on_insufficient_balance() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        deal(quoteToken, redeemer, 50e18);
        redemptionVault.setStatus(1, 1);

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.InsufficientBalanceException.selector);
        gateway.withdraw(99e18);
    }

    /// @notice U:[MID-G-11]: `transferRedeemer` reassigns ownership when allowed
    /// @dev Transferred redeemers are removed from pending sets (one-time transfer; collateral zeroed for recipient)
    function test_U_MID_G_11_transferRedeemer_works() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        _setTransferAllowedFor(address(account));

        vm.prank(address(account));
        gateway.transferRedeemer(redeemer, newAccount);

        assertEq(gateway.pendingRedeemers(address(account)).length, 0, "Redeemer still pending for old account");
        assertEq(gateway.pendingRedeemers(newAccount).length, 0, "Transferred redeemer should not be pending");
        assertEq(MidasRedeemer(redeemer).account(), newAccount, "Redeemer account not updated");

        // Ownership is retained via accountToRedeemers; new owner can withdraw stranded funds.
        deal(quoteToken, redeemer, 50e18);
        vm.prank(newAccount);
        gateway.withdrawFromRedeemer(redeemer, 50e18);
        assertEq(IERC20(quoteToken).balanceOf(newAccount), 50e18, "New account did not receive quote token");
    }

    /// @notice U:[MID-G-12]: `transferRedeemer` reverts when transfer not allowed
    function test_U_MID_G_12_transferRedeemer_reverts_when_not_allowed() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        _clearTransferAllowed();

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.RedeemerTransferNotAllowedException.selector);
        gateway.transferRedeemer(redeemer, newAccount);
    }

    /// @notice U:[MID-G-12A]: `transferRedeemer` reverts when a different account is unlocked
    function test_U_MID_G_12A_transferRedeemer_reverts_when_other_account_unlocked() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        _setTransferAllowedFor(newAccount);

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.RedeemerTransferNotAllowedException.selector);
        gateway.transferRedeemer(redeemer, newAccount);
    }

    /// @notice U:[MID-G-13]: `transferRedeemer` reverts when redeemer is not owned by caller
    function test_U_MID_G_13_transferRedeemer_reverts_when_not_owned() public {
        _setTransferAllowedFor(address(account));

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.RedeemerTransferNotAllowedException.selector);
        gateway.transferRedeemer(makeAddr("UNKNOWN_REDEEMER"), newAccount);
    }

    /// @notice U:[MID-G-13A]: `transferRedeemer` can only be used once per redeemer
    function test_U_MID_G_13A_transferRedeemer_can_only_be_used_once() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        _setTransferAllowedFor(address(account));

        vm.prank(address(account));
        gateway.transferRedeemer(redeemer, newAccount);

        _setTransferAllowedFor(newAccount);
        vm.prank(newAccount);
        vm.expectRevert(IMidasGateway.RedeemerTransferNotAllowedException.selector);
        gateway.transferRedeemer(redeemer, address(account));
    }

    /// @notice U:[MID-G-14]: `requestRedeem` reverts after reaching the max pending redeemers
    function test_U_MID_G_14_requestRedeem_reverts_on_max_pending() public {
        uint256 count = 10;
        deal(mToken, address(account), (count + 1) * 1e18);
        account.approveToken(mToken, address(gateway), (count + 1) * 1e18);

        vm.startPrank(address(account));
        for (uint256 i = 0; i < count; ++i) {
            gateway.requestRedeem(1e18, "");
        }

        vm.expectRevert(IMidasGateway.MaxPendingRedeemersPerAccountException.selector);
        gateway.requestRedeem(1e18, "");
        vm.stopPrank();
    }

    /// @notice U:[MID-G-15]: `requestRedeem` logs redemption when logger is configured
    function test_U_MID_G_15_requestRedeem_logs_when_logger_configured() public {
        RedemptionLogger logger = new RedemptionLogger(address(this));
        RedemptionLoggerAddressProviderMock loggerAddressProvider =
            new RedemptionLoggerAddressProviderMock(address(logger));
        MidasGateway gatewayWithLogger = new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            quoteToken,
            false,
            address(0),
            false,
            REDEMPTION_DURATION,
            true, // withDelayedWithdrawals
            address(loggerAddressProvider)
        );
        logger.setGatewayAllowed(address(gatewayWithLogger), true);

        uint256 amountMToken = 100e18;
        bytes memory extraData = abi.encode(uint256(42));

        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gatewayWithLogger), amountMToken);

        vm.prank(address(account));
        gatewayWithLogger.requestRedeem(amountMToken, extraData);

        address redeemer = gatewayWithLogger.pendingRedeemers(address(account))[0];
        IRedemptionLogger.RedemptionLog memory log = logger.redemptionLogs(redeemer);
        assertEq(log.creditAccount, address(account), "Incorrect logged credit account");
        assertEq(log.redeemer, redeemer, "Incorrect logged redeemer");
        assertEq(log.extraData, extraData, "Incorrect logged extraData");
    }

    function _deployAccessControlledGateway(bool checkBorrowerGreenlist)
        internal
        returns (MidasGateway controlledGateway, ContractsRegisterMock contractsRegister)
    {
        MidasAccessControlMock accessControl = new MidasAccessControlMock();
        issuanceVault.setAccessControl(address(accessControl));
        redemptionVault.setAccessControl(address(accessControl));

        contractsRegister = new ContractsRegisterMock();
        MarketConfiguratorMock marketConfigurator = new MarketConfiguratorMock(address(contractsRegister));

        controlledGateway = new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            quoteToken,
            true,
            address(marketConfigurator),
            checkBorrowerGreenlist,
            REDEMPTION_DURATION,
            true,
            address(addressProvider)
        );
    }
}
