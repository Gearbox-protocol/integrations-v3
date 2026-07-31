// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasGateway} from "../../../../integrations/midas/MidasGateway.sol";
import {MidasRedeemer} from "../../../../integrations/midas/MidasRedeemer.sol";
import {MidasDegenNFT} from "../../../../integrations/midas/MidasDegenNFT.sol";
import {MidasRedemptionVaultPhantomToken} from "../../../../integrations/midas/MidasRedemptionVaultPhantomToken.sol";
import {IMidasGateway, MidasMode} from "../../../../integrations/midas/interfaces/IMidasGateway.sol";
import {ICAChecker} from "../../../../integrations/common/interfaces/ICAChecker.sol";
import {STANDARD_GREENLISTED_ROLE} from "../../../../integrations/midas/interfaces/external/IMidasAccessControl.sol";
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

/// @dev Minimal redemption vault used for redemption requests.
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

    bool internal _supportsGreenlistedRole;
    bytes32 internal _greenlistedRole;

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

    function setGreenlistedRole(bytes32 role) external {
        _supportsGreenlistedRole = true;
        _greenlistedRole = role;
    }

    function clearGreenlistedRole() external {
        _supportsGreenlistedRole = false;
        _greenlistedRole = bytes32(0);
    }

    function greenlistedRole() external view returns (bytes32) {
        if (!_supportsGreenlistedRole) revert("greenlistedRole unsupported");
        return _greenlistedRole;
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
    MidasRedemptionVaultMock redemptionVault;
    MidasDataFeedMock dataFeed;
    CreditManagerMock creditManager;
    CreditAccountMock account;
    ContractsRegisterMock contractsRegister;
    MarketConfiguratorMock marketConfigurator;
    RedemptionLogger redemptionLogger;

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
        redemptionVault = new MidasRedemptionVaultMock(mToken, address(dataFeed));
        creditManager = new CreditManagerMock();
        redemptionLogger = new RedemptionLogger(address(this));
        addressProvider = new RedemptionLoggerAddressProviderMock(address(redemptionLogger));

        contractsRegister = new ContractsRegisterMock();
        marketConfigurator = new MarketConfiguratorMock(address(contractsRegister));

        gateway = new MidasGateway(
            address(redemptionVault),
            quoteToken,
            MidasMode.Permissionless,
            address(marketConfigurator),
            REDEMPTION_DURATION,
            true, // withDelayedWithdrawals
            address(addressProvider)
        );
        redemptionLogger.setGatewayAllowed(address(gateway), true);
        transferMaster = gateway.transferMaster();

        account = new CreditAccountMock(address(creditManager));
        creditManager.setBorrower(address(account), borrower);
        contractsRegister.setCreditManager(address(creditManager), true);
    }

    function _setTransferAllowedFor(address account_) internal {
        // Slot 0 packs `ReentrancyGuardTrait._reentrancyStatus` (uint8, NOT_ENTERED = 1) with
        // `MidasLiquidator.transferableRedeemerOwner` (address).
        uint256 packed = uint256(uint8(1)) | (uint256(uint160(account_)) << 8);
        vm.store(transferMaster, bytes32(uint256(0)), bytes32(packed));
    }

    function _clearTransferAllowed() internal {
        // Keep `_reentrancyStatus` as NOT_ENTERED and clear the transferable owner.
        vm.store(transferMaster, bytes32(uint256(0)), bytes32(uint256(uint8(1))));
    }

    /// @notice U:[MID-G-1]: Constructor works as expected
    function test_U_MID_G_01_constructor_works() public view {
        assertEq(gateway.contractType(), "GATEWAY::MIDAS", "Incorrect contract type");
        assertEq(gateway.version(), 3_11, "Incorrect version");
        assertEq(gateway.midasRedemptionVault(), address(redemptionVault), "Incorrect redemption vault");
        assertEq(gateway.mToken(), mToken, "Incorrect mToken");
        assertEq(gateway.quoteToken(), quoteToken, "Incorrect quote token");
        assertTrue(uint8(gateway.mode()) == uint8(MidasMode.Permissionless), "Incorrect mode");
        assertTrue(gateway.phantomToken() != address(0), "Phantom token not deployed");
        assertEq(
            MidasRedemptionVaultPhantomToken(gateway.phantomToken()).gateway(), address(gateway), "Incorrect PT gateway"
        );
        assertTrue(gateway.transferMaster() != address(0), "Transfer master not deployed");
        assertEq(
            IVersion(gateway.transferMaster()).contractType(), "RWA_LIQUIDATOR::MIDAS", "Incorrect transfer master type"
        );
        assertEq(gateway.expectedRedemptionDuration(), REDEMPTION_DURATION, "Incorrect redemption duration");
        assertEq(gateway.redemptionLogger(), address(redemptionLogger), "Incorrect redemption logger");
        assertTrue(gateway.masterRedeemer() != address(0), "Master redeemer not set");
        assertEq(gateway.degenNFT(), address(0), "Degen NFT should not be deployed in Permissionless");
        assertEq(gateway.accessControl(), address(0), "Access control should be zero in Permissionless");
        assertEq(gateway.allowedMarketConfigurator(), address(marketConfigurator), "Incorrect market configurator");
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
            address(redemptionVault),
            quoteToken,
            MidasMode.Permissionless,
            address(marketConfigurator),
            REDEMPTION_DURATION,
            false, // withDelayedWithdrawals
            address(addressProvider)
        );

        assertEq(gatewayWithoutPhantomToken.phantomToken(), address(0), "Phantom token should not be deployed");
    }

    /// @notice U:[MID-G-1C]: Constructor deploys degen NFT only in Permissioned mode
    function test_U_MID_G_01C_constructor_deploys_degen_nft_in_permissioned_mode() public {
        (MidasGateway permissionedGateway,, MidasAccessControlMock accessControl) =
            _deployAccessControlledGatewayWithAC(MidasMode.Permissioned);

        assertTrue(permissionedGateway.degenNFT() != address(0), "Degen NFT should be deployed");
        MidasDegenNFT degenNFT = MidasDegenNFT(permissionedGateway.degenNFT());
        assertEq(degenNFT.gateway(), address(permissionedGateway), "Incorrect degen NFT gateway");
        assertEq(degenNFT.accessControl(), address(accessControl), "Incorrect degen NFT access control");
        assertEq(degenNFT.greenlistedRole(), STANDARD_GREENLISTED_ROLE, "Incorrect degen NFT greenlisted role");
        assertEq(degenNFT.contractType(), "DEGEN_NFT::MIDAS", "Incorrect degen NFT contract type");

        (MidasGateway restrictedGateway,,) = _deployAccessControlledGatewayWithAC(MidasMode.RestrictedInterface);
        assertEq(restrictedGateway.degenNFT(), address(0), "Degen NFT should not be deployed in RestrictedInterface");
    }

    /// @notice U:[MID-G-2A]: Constructor reads access control from the redemption vault
    function test_U_MID_G_02A_constructor_reads_access_control() public {
        address accessControl = makeAddr("ACCESS_CONTROL");
        redemptionVault.setAccessControl(accessControl);

        MidasGateway controlledGateway = new MidasGateway(
            address(redemptionVault),
            quoteToken,
            MidasMode.RestrictedInterface,
            address(marketConfigurator),
            REDEMPTION_DURATION,
            true,
            address(addressProvider)
        );

        assertEq(controlledGateway.accessControl(), accessControl, "Incorrect access control");
        assertTrue(uint8(controlledGateway.mode()) == uint8(MidasMode.RestrictedInterface), "Incorrect mode");
        assertEq(controlledGateway.greenlistedRole(), STANDARD_GREENLISTED_ROLE, "Should fall back to standard role");
        assertEq(
            controlledGateway.allowedMarketConfigurator(), address(marketConfigurator), "Incorrect market configurator"
        );
        assertEq(controlledGateway.degenNFT(), address(0), "Degen NFT should not be deployed");
    }

    /// @notice U:[MID-G-2C]: Constructor reverts when market configurator is not set
    function test_U_MID_G_02C_constructor_reverts_when_market_configurator_not_set() public {
        vm.expectRevert(ICAChecker.MarketConfiguratorNotSetException.selector);
        new MidasGateway(
            address(redemptionVault),
            quoteToken,
            MidasMode.Permissionless,
            address(0),
            REDEMPTION_DURATION,
            true,
            address(addressProvider)
        );
    }

    /// @notice U:[MID-G-3]: Constructor reverts when non-permissionless mode has no vault access control
    function test_U_MID_G_03_constructor_reverts_when_access_control_not_set() public {
        vm.expectRevert(IMidasGateway.AccessControlNotSetException.selector);
        new MidasGateway(
            address(redemptionVault),
            quoteToken,
            MidasMode.RestrictedInterface,
            address(marketConfigurator),
            REDEMPTION_DURATION,
            true,
            address(addressProvider)
        );
    }

    /// @notice U:[MID-G-6]: Gateways revert for non-credit-account callers in all modes
    function test_U_MID_G_06_reverts_for_non_credit_account_caller() public {
        address notCreditAccount = address(new NonCreditAccountMock());

        vm.prank(notCreditAccount);
        vm.expectRevert(ICAChecker.CreditAccountNotEligibleException.selector);
        gateway.requestRedeem(1, "");
    }

    /// @notice U:[MID-G-6A]: Access-controlled gateways revert for non-credit-account callers
    function test_U_MID_G_06A_reverts_for_ineligible_caller_when_access_controlled() public {
        (MidasGateway controlledGateway,) = _deployAccessControlledGateway(MidasMode.RestrictedInterface);

        address notCreditAccount = address(new NonCreditAccountMock());

        vm.prank(notCreditAccount);
        vm.expectRevert(ICAChecker.CreditAccountNotEligibleException.selector);
        controlledGateway.requestRedeem(1, "");
    }

    /// @notice U:[MID-G-7]: Gateways revert when borrower is not set
    function test_U_MID_G_07_reverts_when_borrower_not_set() public {
        CreditAccountMock accountNoBorrower = new CreditAccountMock(address(creditManager));

        vm.prank(address(accountNoBorrower));
        vm.expectRevert(ICAChecker.CreditAccountNotEligibleException.selector);
        gateway.requestRedeem(1, "");
    }

    /// @notice U:[MID-G-7A]: Gateways revert when credit manager is not registered
    function test_U_MID_G_07A_reverts_when_credit_manager_not_registered() public {
        contractsRegister.setCreditManager(address(creditManager), false);

        vm.prank(address(account));
        vm.expectRevert(ICAChecker.CreditAccountNotEligibleException.selector);
        gateway.requestRedeem(1, "");
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
        assertTrue(MidasRedeemer(redeemer).alreadyRequested(), "Redeemer should be marked as requested");
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

    /// @notice U:[MID-G-9A]: `withdraw` drains redeemers in order and stops on the one that covers the remainder
    /// @dev The partially drained redeemer keeps its leftover balance and stays pending; the fully
    ///      drained one is removed since its request is no longer pending
    function test_U_MID_G_09A_withdraw_drains_redeemers_until_amount_is_covered() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), 2 * amountMToken);
        account.approveToken(mToken, address(gateway), 2 * amountMToken);

        vm.startPrank(address(account));
        gateway.requestRedeem(amountMToken, "");
        gateway.requestRedeem(amountMToken, "");
        vm.stopPrank();

        address[] memory redeemers = gateway.pendingRedeemers(address(account));

        // First request is fulfilled and its redeemer holds less than the withdrawn amount,
        // second one is still pending with more than the remainder.
        deal(quoteToken, redeemers[0], 40e18);
        redemptionVault.setStatus(1, 1);
        deal(quoteToken, redeemers[1], 60e18);

        vm.prank(address(account));
        gateway.withdraw(70e18);

        assertEq(IERC20(quoteToken).balanceOf(address(account)), 70e18, "Account did not receive quote token");
        assertEq(IERC20(quoteToken).balanceOf(redeemers[0]), 0, "First redeemer should be fully drained");
        assertEq(IERC20(quoteToken).balanceOf(redeemers[1]), 30e18, "Second redeemer should keep the leftover");

        address[] memory pending = gateway.pendingRedeemers(address(account));
        assertEq(pending.length, 1, "Only the partially drained redeemer should stay pending");
        assertEq(pending[0], redeemers[1], "Wrong redeemer left pending");
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
        CreditAccountMock recipient = new CreditAccountMock(address(creditManager));
        creditManager.setBorrower(address(recipient), makeAddr("RECIPIENT_BORROWER"));

        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        _setTransferAllowedFor(address(account));

        vm.prank(address(account));
        gateway.transferRedeemer(redeemer, address(recipient));

        _setTransferAllowedFor(address(recipient));
        vm.prank(address(recipient));
        vm.expectRevert(IMidasGateway.RedeemerTransferNotAllowedException.selector);
        gateway.transferRedeemer(redeemer, address(account));
    }

    /// @notice U:[MID-G-13B]: `transferRedeemer` reverts on self-transfer
    /// @dev Transferring to self would drop the redeemer from the pending set (with no way back)
    ///      while keeping ownership, silently removing the position from collateral valuation
    function test_U_MID_G_13B_transferRedeemer_reverts_on_self_transfer() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        _setTransferAllowedFor(address(account));

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.RedeemerTransferNotAllowedException.selector);
        gateway.transferRedeemer(redeemer, address(account));
    }

    /// @notice U:[MID-G-13C]: `transferRedeemer` reverts when transferring to the zero address
    /// @dev The redeemer would be frozen forever: withdrawals to the zero address revert and
    ///      it can no longer be transferred since it is no longer pending
    function test_U_MID_G_13C_transferRedeemer_reverts_on_zero_new_account() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        _setTransferAllowedFor(address(account));

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.RedeemerTransferNotAllowedException.selector);
        gateway.transferRedeemer(redeemer, address(0));
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
            address(redemptionVault),
            quoteToken,
            MidasMode.Permissionless,
            address(marketConfigurator),
            REDEMPTION_DURATION,
            true,
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

    /// @notice U:[MID-G-16]: Constructor reads custom greenlisted role from redemption vault
    function test_U_MID_G_16_constructor_reads_custom_greenlisted_role() public {
        bytes32 customRole = keccak256("CUSTOM_GREENLISTED_ROLE");
        address accessControl = makeAddr("ACCESS_CONTROL");
        redemptionVault.setAccessControl(accessControl);
        redemptionVault.setGreenlistedRole(customRole);

        MidasGateway controlledGateway = new MidasGateway(
            address(redemptionVault),
            quoteToken,
            MidasMode.RestrictedInterface,
            address(marketConfigurator),
            REDEMPTION_DURATION,
            true,
            address(addressProvider)
        );

        assertEq(controlledGateway.greenlistedRole(), customRole, "Incorrect greenlisted role");
    }

    /// @notice U:[MID-G-17]: Constructor falls back to STANDARD_GREENLISTED_ROLE when vault has no custom role
    function test_U_MID_G_17_constructor_falls_back_to_standard_greenlisted_role() public {
        address accessControl = makeAddr("ACCESS_CONTROL");
        redemptionVault.setAccessControl(accessControl);
        // greenlistedRole unsupported => falls back to STANDARD

        MidasGateway controlledGateway = new MidasGateway(
            address(redemptionVault),
            quoteToken,
            MidasMode.RestrictedInterface,
            address(marketConfigurator),
            REDEMPTION_DURATION,
            true,
            address(addressProvider)
        );

        assertEq(controlledGateway.greenlistedRole(), STANDARD_GREENLISTED_ROLE, "Should fall back to standard role");
    }

    /// @notice U:[MID-G-19]: `receiveGreenlist` grants the greenlisted role in Permissioned mode
    function test_U_MID_G_19_receiveGreenlist_works_in_permissioned_mode() public {
        (
            MidasGateway permissionedGateway,
            ContractsRegisterMock contractsRegister,
            MidasAccessControlMock accessControl
        ) = _deployAccessControlledGatewayWithAC(MidasMode.Permissioned);
        contractsRegister.setCreditManager(address(creditManager), true);
        accessControl.grantRole(STANDARD_GREENLISTED_ROLE, borrower);

        assertFalse(accessControl.hasRole(STANDARD_GREENLISTED_ROLE, address(account)), "Account already greenlisted");

        vm.prank(address(account));
        permissionedGateway.receiveGreenlist();

        assertTrue(accessControl.hasRole(STANDARD_GREENLISTED_ROLE, address(account)), "Account not greenlisted");
    }

    /// @notice U:[MID-G-20]: `receiveGreenlist` reverts outside Permissioned mode
    function test_U_MID_G_20_receiveGreenlist_reverts_in_non_permissioned_mode() public {
        (MidasGateway restrictedGateway, ContractsRegisterMock contractsRegister,) =
            _deployAccessControlledGatewayWithAC(MidasMode.RestrictedInterface);
        contractsRegister.setCreditManager(address(creditManager), true);

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.GreenlistRequestedInNonPermissionedModeException.selector);
        restrictedGateway.receiveGreenlist();

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.GreenlistRequestedInNonPermissionedModeException.selector);
        gateway.receiveGreenlist();
    }

    /// @notice U:[MID-G-21]: `isEligibleAccountOwner` reflects Permissioned greenlist requirements
    function test_U_MID_G_21_isEligibleAccountOwner_works() public {
        (bool eligible, address token) = gateway.isEligibleAccountOwner(borrower);
        assertTrue(eligible, "Permissionless owners should be eligible");
        assertEq(token, mToken, "Incorrect mToken");

        (MidasGateway restrictedGateway,,) = _deployAccessControlledGatewayWithAC(MidasMode.RestrictedInterface);
        (eligible, token) = restrictedGateway.isEligibleAccountOwner(borrower);
        assertTrue(eligible, "RestrictedInterface owners should be eligible");
        assertEq(token, mToken, "Incorrect mToken");

        (MidasGateway permissionedGateway,, MidasAccessControlMock accessControl) =
            _deployAccessControlledGatewayWithAC(MidasMode.Permissioned);
        (eligible, token) = permissionedGateway.isEligibleAccountOwner(borrower);
        assertFalse(eligible, "Permissioned owner should not be eligible yet");
        assertEq(token, mToken, "Incorrect mToken");

        accessControl.grantRole(STANDARD_GREENLISTED_ROLE, borrower);
        (eligible, token) = permissionedGateway.isEligibleAccountOwner(borrower);
        assertTrue(eligible, "Greenlisted owner should be eligible");
        assertEq(token, mToken, "Incorrect mToken");
    }

    /// @notice U:[MID-G-22]: Permissioned mode rejects non-greenlisted borrowers
    function test_U_MID_G_22_permissioned_mode_reverts_for_non_greenlisted_borrower() public {
        (MidasGateway permissionedGateway, ContractsRegisterMock contractsRegister,) =
            _deployAccessControlledGatewayWithAC(MidasMode.Permissioned);
        contractsRegister.setCreditManager(address(creditManager), true);

        deal(mToken, address(account), 1e18);
        account.approveToken(mToken, address(permissionedGateway), 1e18);

        vm.prank(address(account));
        vm.expectRevert(ICAChecker.CreditAccountNotEligibleException.selector);
        permissionedGateway.requestRedeem(1e18, "");
    }

    /// @notice U:[MID-G-23]: `transferRedeemer` reverts when new account is not greenlisted in Permissioned mode
    function test_U_MID_G_23_transferRedeemer_reverts_when_new_account_not_greenlisted() public {
        (
            MidasGateway permissionedGateway,
            ContractsRegisterMock contractsRegister,
            MidasAccessControlMock accessControl
        ) = _deployAccessControlledGatewayWithAC(MidasMode.Permissioned);
        contractsRegister.setCreditManager(address(creditManager), true);
        accessControl.grantRole(STANDARD_GREENLISTED_ROLE, borrower);

        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(permissionedGateway), amountMToken);

        vm.prank(address(account));
        permissionedGateway.requestRedeem(amountMToken, "");

        address redeemer = permissionedGateway.pendingRedeemers(address(account))[0];
        // Slot 0 packs reentrancy status with transferableRedeemerOwner on the liquidator.
        uint256 packed = uint256(uint8(1)) | (uint256(uint160(address(account))) << 8);
        vm.store(permissionedGateway.transferMaster(), bytes32(uint256(0)), bytes32(packed));

        vm.prank(address(account));
        vm.expectRevert(IMidasGateway.NewAccountNotGreenlistedException.selector);
        permissionedGateway.transferRedeemer(redeemer, newAccount);
    }

    /// @notice U:[MID-G-24A]: Redeemers are greenlisted once on creation and never revoked
    function test_U_MID_G_24A_requestRedeem_grants_greenlist_permanently() public {
        (
            MidasGateway controlledGateway,
            ContractsRegisterMock contractsRegister,
            MidasAccessControlMock accessControl
        ) = _deployAccessControlledGatewayWithAC(MidasMode.RestrictedInterface);
        contractsRegister.setCreditManager(address(creditManager), true);

        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(controlledGateway), amountMToken);

        vm.prank(address(account));
        controlledGateway.requestRedeem(amountMToken, "");

        address redeemer = controlledGateway.pendingRedeemers(address(account))[0];
        assertTrue(
            accessControl.hasRole(STANDARD_GREENLISTED_ROLE, redeemer), "Redeemer should be greenlisted after request"
        );

        deal(quoteToken, redeemer, 50e18);
        redemptionVault.setStatus(1, 1);
        vm.prank(address(account));
        controlledGateway.withdraw(50e18);

        assertTrue(
            accessControl.hasRole(STANDARD_GREENLISTED_ROLE, redeemer),
            "Redeemer greenlist should not be revoked after withdraw"
        );
    }

    /// @notice U:[MID-G-30]: `withdrawFromRedeemer` can sweep stranded mToken with a zero quote amount
    function test_U_MID_G_30_withdrawFromRedeemer_sweeps_stranded_mToken() public {
        uint256 amountMToken = 100e18;
        deal(mToken, address(account), amountMToken);
        account.approveToken(mToken, address(gateway), amountMToken);

        vm.prank(address(account));
        gateway.requestRedeem(amountMToken, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        uint256 stranded = 7e18;
        deal(mToken, redeemer, stranded);

        vm.prank(address(account));
        gateway.withdrawFromRedeemer(redeemer, 0);

        assertEq(IERC20(mToken).balanceOf(address(account)), stranded, "Account did not receive stranded mToken");
        assertEq(IERC20(mToken).balanceOf(redeemer), 0, "Redeemer should not retain stranded mToken");
    }

    function _deployAccessControlledGateway(MidasMode mode_)
        internal
        returns (MidasGateway controlledGateway, ContractsRegisterMock contractsRegister)
    {
        (controlledGateway, contractsRegister,) = _deployAccessControlledGatewayWithAC(mode_);
    }

    function _deployAccessControlledGatewayWithAC(MidasMode mode_)
        internal
        returns (
            MidasGateway controlledGateway,
            ContractsRegisterMock contractsRegister,
            MidasAccessControlMock accessControl
        )
    {
        accessControl = new MidasAccessControlMock();
        redemptionVault.setAccessControl(address(accessControl));

        contractsRegister = new ContractsRegisterMock();
        MarketConfiguratorMock marketConfigurator = new MarketConfiguratorMock(address(contractsRegister));

        controlledGateway = new MidasGateway(
            address(redemptionVault),
            quoteToken,
            mode_,
            address(marketConfigurator),
            REDEMPTION_DURATION,
            true,
            address(addressProvider)
        );
        redemptionLogger.setGatewayAllowed(address(controlledGateway), true);
    }
}
