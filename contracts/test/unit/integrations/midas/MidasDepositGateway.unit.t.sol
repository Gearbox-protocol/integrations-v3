// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasDepositGateway} from "../../../../integrations/midas/MidasDepositGateway.sol";
import {MidasDepositor} from "../../../../integrations/midas/MidasDepositor.sol";
import {MidasLiquidator} from "../../../../integrations/midas/MidasLiquidator.sol";
import {MidasDepositVaultPhantomToken} from "../../../../integrations/midas/MidasDepositVaultPhantomToken.sol";
import {IMidasDepositGateway} from "../../../../integrations/midas/interfaces/IMidasDepositGateway.sol";
import {MidasMode} from "../../../../integrations/midas/interfaces/IMidasRedemptionGateway.sol";
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

contract MidasDepositVaultMockForGateway {
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
    address public accessControl;

    uint256 public currentRequestId;
    mapping(uint256 => Request) internal _requests;

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
        uint256,
        address recipientInstant
    ) external returns (uint256, uint256) {
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

/// @title MidasDepositGateway unit test
/// @notice U:[MID-DG]: Unit tests for MidasDepositGateway
contract MidasDepositGatewayUnitTest is Test {
    MidasDepositGateway gateway;
    MidasDepositVaultMockForGateway depositVault;
    MidasLiquidator liquidator;
    RedemptionLogger redemptionLogger;
    RedemptionLoggerAddressProviderMock addressProvider;

    address mToken;
    address tokenIn;
    address marketConfigurator;
    address creditManager;
    address creditAccount;
    address borrower;

    bytes32 constant REFERRER_ID = keccak256("GEARBOX");
    uint256 constant DEPOSIT_DURATION = 1 days;

    function setUp() public {
        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        tokenIn = address(new ERC20Mock("USDC", "USDC", 18));
        borrower = makeAddr("BORROWER");

        creditManager = address(new CreditManagerMock());
        ContractsRegisterMock contractsRegister = new ContractsRegisterMock();
        marketConfigurator = address(new MarketConfiguratorMock(address(contractsRegister)));
        creditAccount = address(new CreditAccountMock(creditManager));
        CreditManagerMock(creditManager).setBorrower(creditAccount, borrower);
        contractsRegister.setCreditManager(creditManager, true);

        depositVault = new MidasDepositVaultMockForGateway(mToken, address(new MidasDataFeedMock()));
        liquidator = new MidasLiquidator();
        redemptionLogger = new RedemptionLogger(address(this));
        addressProvider = new RedemptionLoggerAddressProviderMock(address(redemptionLogger));

        gateway = new MidasDepositGateway(
            address(depositVault),
            tokenIn,
            REFERRER_ID,
            MidasMode.Permissionless,
            marketConfigurator,
            DEPOSIT_DURATION,
            true,
            true,
            address(liquidator),
            address(addressProvider)
        );
        redemptionLogger.setGatewayAllowed(address(gateway), true);
    }

    /// @notice U:[MID-DG-1]: Constructor works as expected
    function test_U_MID_DG_01_constructor_works() public view {
        assertEq(gateway.contractType(), "GATEWAY::MIDAS_DEPOSIT", "Incorrect contract type");
        assertEq(gateway.version(), 3_10, "Incorrect version");
        assertEq(gateway.midasDepositVault(), address(depositVault), "Incorrect deposit vault");
        assertEq(gateway.mToken(), mToken, "Incorrect mToken");
        assertEq(gateway.tokenIn(), tokenIn, "Incorrect tokenIn");
        assertEq(gateway.referrerId(), REFERRER_ID, "Incorrect referrerId");
        assertEq(gateway.transferMaster(), address(liquidator), "Incorrect shared transfer master");
        assertEq(IVersion(gateway.transferMaster()).version(), 3_12, "Incorrect liquidator version");
        assertTrue(gateway.phantomToken() != address(0), "Phantom token not deployed");
        assertEq(
            MidasDepositVaultPhantomToken(gateway.phantomToken()).underlying(), mToken, "Phantom underlying not mToken"
        );
        assertEq(gateway.expectedDepositDuration(), DEPOSIT_DURATION, "Incorrect duration");
        assertEq(gateway.redemptionLogger(), address(redemptionLogger), "Incorrect redemption logger");
    }

    /// @notice U:[MID-DG-2]: `requestDeposit` creates a depositor and submits the request
    function test_U_MID_DG_02_requestDeposit_works() public {
        deal(tokenIn, creditAccount, 100e18);
        CreditAccountMock(creditAccount).approveToken(tokenIn, address(gateway), type(uint256).max);

        vm.prank(creditAccount);
        gateway.requestDeposit(100e18, "");

        address[] memory pending = gateway.pendingDepositors(creditAccount);
        assertEq(pending.length, 1, "Should create one pending depositor");
        assertEq(MidasDepositor(pending[0]).requestId(), 1, "Incorrect request id");
        assertEq(MidasDepositor(pending[0]).account(), creditAccount, "Incorrect depositor account");
        assertEq(IERC20(tokenIn).balanceOf(address(depositVault)), 100e18, "Vault did not receive tokenIn");
    }

    /// @notice U:[MID-DG-3]: Hybrid deposit mints instant share to the credit account
    function test_U_MID_DG_03_requestDepositHybrid_works() public {
        deal(tokenIn, creditAccount, 100e18);
        deal(mToken, address(depositVault), 100e18);
        CreditAccountMock(creditAccount).approveToken(tokenIn, address(gateway), type(uint256).max);

        vm.prank(creditAccount);
        gateway.requestDepositHybrid(100e18, 2_500, 20e18, "");

        assertEq(IERC20(mToken).balanceOf(creditAccount), 25e18, "CA should receive instant mToken");
        assertEq(gateway.pendingDepositors(creditAccount).length, 1, "Should keep delayed depositor");
    }

    /// @notice U:[MID-DG-4]: `withdraw` drains claimable mToken from depositors
    function test_U_MID_DG_04_withdraw_works() public {
        deal(tokenIn, creditAccount, 100e18);
        CreditAccountMock(creditAccount).approveToken(tokenIn, address(gateway), type(uint256).max);

        vm.prank(creditAccount);
        gateway.requestDeposit(100e18, "");

        address depositor = gateway.pendingDepositors(creditAccount)[0];
        deal(mToken, depositor, 80e18);
        depositVault.setStatus(1, 1); // APPROVED → pending amount drops to 0

        vm.prank(creditAccount);
        gateway.withdraw(50e18);

        assertEq(IERC20(mToken).balanceOf(creditAccount), 50e18, "CA did not receive mToken");
        assertEq(IERC20(mToken).balanceOf(depositor), 30e18, "Depositor leftover incorrect");
    }

    /// @notice U:[MID-DG-5]: `transferDepositor` works when unlocked by the shared liquidator
    function test_U_MID_DG_05_transferDepositor_works_when_unlocked() public {
        deal(tokenIn, creditAccount, 100e18);
        CreditAccountMock(creditAccount).approveToken(tokenIn, address(gateway), type(uint256).max);

        vm.prank(creditAccount);
        gateway.requestDeposit(100e18, "");

        address depositor = gateway.pendingDepositors(creditAccount)[0];
        address newAccount = address(new CreditAccountMock(creditManager));
        CreditManagerMock(creditManager).setBorrower(newAccount, borrower);

        // Unlock transfers the same way the liquidator does during liquidation.
        vm.store(
            address(liquidator),
            bytes32(uint256(0)),
            bytes32(uint256(uint8(1)) | (uint256(uint160(creditAccount)) << 8))
        );

        vm.prank(creditAccount);
        gateway.transferDepositor(depositor, newAccount);

        assertEq(gateway.pendingDepositors(creditAccount).length, 0, "Source should lose pending depositor");
        assertEq(MidasDepositor(depositor).account(), newAccount, "Depositor account not updated");
        assertEq(gateway.depositors(newAccount).length, 1, "Target should own depositor");
    }

    /// @notice U:[MID-DG-6]: Non-eligible callers cannot request deposits
    function test_U_MID_DG_06_requestDeposit_reverts_for_non_eligible_account() public {
        address notCA = makeAddr("NOT_CA");
        deal(tokenIn, notCA, 100e18);

        vm.prank(notCA);
        vm.expectRevert();
        gateway.requestDeposit(100e18, "");
    }

    /// @notice U:[MID-DG-7]: `requestDeposit` logs via the shared redemption logger
    function test_U_MID_DG_07_requestDeposit_logs_when_logger_configured() public {
        bytes memory extraData = abi.encode(uint256(42));
        deal(tokenIn, creditAccount, 100e18);
        CreditAccountMock(creditAccount).approveToken(tokenIn, address(gateway), type(uint256).max);

        vm.prank(creditAccount);
        gateway.requestDeposit(100e18, extraData);

        address depositor = gateway.pendingDepositors(creditAccount)[0];
        IRedemptionLogger.RedemptionLog memory log = redemptionLogger.redemptionLogs(depositor);
        assertEq(log.creditAccount, creditAccount, "Incorrect logged credit account");
        assertEq(log.redeemer, depositor, "Incorrect logged depositor");
        assertEq(log.extraData, extraData, "Incorrect logged extraData");
    }
}
