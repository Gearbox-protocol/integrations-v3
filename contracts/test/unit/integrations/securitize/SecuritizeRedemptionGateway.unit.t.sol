// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {SecuritizeRedemptionGateway} from "../../../../integrations/securitize/SecuritizeRedemptionGateway.sol";
import {
    SecuritizeRedemptionPhantomToken
} from "../../../../integrations/securitize/SecuritizeRedemptionPhantomToken.sol";
import {SecuritizeRedeemer} from "../../../../integrations/securitize/SecuritizeRedeemer.sol";
import {IAddressProvider} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAddressProvider.sol";
import {
    ISecuritizeNAVProvider
} from "../../../../integrations/securitize/interfaces/external/ISecuritizeNAVProvider.sol";
import {
    ISecuritizeWhitelister
} from "../../../../integrations/securitize/interfaces/external/ISecuritizeWhitelister.sol";
import {
    ISecuritizeGatewayTransferMaster
} from "../../../../integrations/securitize/interfaces/ISecuritizeGatewayTransferMaster.sol";
import {
    ISecuritizeRedemptionGateway
} from "../../../../integrations/securitize/interfaces/ISecuritizeRedemptionGateway.sol";
import {
    ISecuritizeRegistryService
} from "../../../../integrations/securitize/interfaces/external/ISecuritizeRegistryService.sol";
import {RedemptionLogger} from "../../../../integrations/common/RedemptionLogger.sol";
import {
    IRedemptionLogger,
    AP_REDEMPTION_LOGGER
} from "../../../../integrations/common/interfaces/IRedemptionLogger.sol";

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

    function priceFeed() external pure returns (address) {
        return address(0);
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
    address public override transferableRedeemerOwner;

    bytes32 public constant override contractType = "MOCK::TRANSFER_MASTER";
    uint256 public constant override version = 3_10;

    function setTransferAllowed(address account) external {
        transferableRedeemerOwner = account;
    }

    function isTransferAllowed(address redeemerOwner) external view override returns (bool) {
        return redeemerOwner == transferableRedeemerOwner;
    }
}

    contract SecuritizeRegistryServiceMock is ISecuritizeRegistryService {
        mapping(address => bool) internal _isWallet;

        function setWallet(address wallet, bool isWallet_) external {
            _isWallet[wallet] = isWallet_;
        }

        function isWallet(address wallet) external view returns (bool) {
            return _isWallet[wallet];
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

    /// @title SecuritizeRedemptionGateway unit test
    /// @notice U:[SRG]: Unit tests for SecuritizeRedemptionGateway
    contract SecuritizeRedemptionGatewayUnitTest is Test {
        SecuritizeRedemptionGateway gateway;
        SecuritizeNAVProviderMock navProvider;
        SecuritizeWhitelisterMock whitelister;
        SecuritizeGatewayTransferMasterMock transferMaster;
        SecuritizeRegistryServiceMock registryService;
        RedemptionLoggerAddressProviderMock addressProvider;

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
            registryService = new SecuritizeRegistryServiceMock();
            registryService.setWallet(newAccount, true);
            addressProvider = new RedemptionLoggerAddressProviderMock(address(0));

            gateway = new SecuritizeRedemptionGateway(
                dsToken,
                stableCoinToken,
                redemptionAccount,
                address(whitelister),
                address(transferMaster),
                address(navProvider),
                address(registryService),
                address(addressProvider)
            );
        }

        /// @notice U:[SRG-1]: Constructor works as expected
        function test_U_SRG_01_constructor_works() public view {
            assertEq(gateway.contractType(), "GATEWAY::SECURITIZE_REDEMPTION");
            assertEq(gateway.version(), 3_11);
            assertEq(gateway.dsToken(), dsToken);
            assertEq(gateway.stableCoinToken(), stableCoinToken);
            assertEq(gateway.redemptionAccount(), redemptionAccount);
            assertEq(gateway.securitizeWhitelister(), address(whitelister));
            assertEq(gateway.transferMaster(), address(transferMaster));
            assertEq(gateway.registryService(), address(registryService));
            assertEq(gateway.redemptionLogger(), address(0), "Incorrect redemption logger");
            assertTrue(gateway.masterRedeemer() != address(0));
            assertTrue(gateway.phantomToken() != address(0), "Phantom token not deployed");
        }

        /// @notice U:[SRG-1B]: Phantom token deployed in constructor has correct parameters
        function test_U_SRG_01B_constructor_deploys_phantom_token_with_correct_params() public view {
            SecuritizeRedemptionPhantomToken phantomToken = SecuritizeRedemptionPhantomToken(gateway.phantomToken());

            assertEq(phantomToken.contractType(), "PHANTOM_TOKEN::SECURITIZE_RD", "Incorrect contract type");
            assertEq(phantomToken.version(), 3_10, "Incorrect version");
            assertEq(phantomToken.redemptionGateway(), address(gateway), "Incorrect redemption gateway");
            assertEq(phantomToken.stableCoinToken(), stableCoinToken, "Incorrect stablecoin token");
            assertEq(phantomToken.decimals(), 6, "Incorrect decimals");
            assertEq(phantomToken.name(), "Securitize pending redemption DS to USDC", "Incorrect name");
            assertEq(phantomToken.symbol(), "srpDS_USDC", "Incorrect symbol");

            (address gw, address underlying) = phantomToken.getPhantomTokenInfo();
            assertEq(gw, address(gateway), "Incorrect gateway from getPhantomTokenInfo");
            assertEq(underlying, stableCoinToken, "Incorrect underlying from getPhantomTokenInfo");

            (address sgw, address sunderlying) = abi.decode(phantomToken.serialize(), (address, address));
            assertEq(sgw, address(gateway), "Incorrect gateway in serialized data");
            assertEq(sunderlying, stableCoinToken, "Incorrect stablecoin in serialized data");
        }

        /// @notice U:[SRG-1A]: zero redeem is a no-op
        function test_U_SRG_01A_redeem_zero_is_noop() public {
            vm.prank(account);
            gateway.redeem(0, "");

            assertEq(gateway.getRedeemers(account).length, 0);
            assertEq(gateway.getUnclaimedRedeemers(account).length, 0);
            assertEq(whitelister.calls(), 0);
        }

        /// @notice U:[SRG-2]: redeem creates a redeemer and executes redemption flow
        function test_U_SRG_02_redeem_works() public {
            navProvider.setRate(2e18);
            deal(dsToken, account, 100e18);

            vm.prank(account);
            IERC20(dsToken).approve(address(gateway), 100e18);

            vm.prank(account);
            gateway.redeem(100e18, "");

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
            gateway.redeem(100e18, "");
            gateway.redeem(200e18, "");
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
            gateway.redeem(100e18, "");

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
            gateway.redeem(100e18, "");

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
            gateway.redeem(100e18, "");

            navProvider.setRate(2e18);
            gateway.redeem(50e18, "");
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
        /// @dev Transferred redeemers are removed from unclaimed sets (one-time transfer; collateral zeroed for recipient)
        function test_U_SRG_07_transferRedeemer_works_when_allowed() public {
            deal(dsToken, account, 100e18);
            vm.prank(account);
            IERC20(dsToken).approve(address(gateway), 100e18);
            vm.prank(account);
            gateway.redeem(100e18, "");

            address redeemer = gateway.getRedeemers(account)[0];
            transferMaster.setTransferAllowed(account);

            vm.prank(account);
            gateway.transferRedeemer(redeemer, newAccount);

            assertEq(gateway.getRedeemers(account).length, 0);
            assertEq(gateway.getUnclaimedRedeemers(account).length, 0);
            assertEq(gateway.getRedeemers(newAccount).length, 1);
            assertEq(gateway.getUnclaimedRedeemers(newAccount).length, 0);
            assertEq(gateway.getRedeemers(newAccount)[0], redeemer);
            assertEq(gateway.getRedemptionAmount(newAccount), 0);

            assertEq(whitelister.calls(), 1);
            assertEq(whitelister.lastCreditAccount(), account);
            assertEq(whitelister.lastHelperAccount(), redeemer);
            assertEq(whitelister.lastToken(), dsToken);

            // Ownership is retained via redeemersByAccount; new owner can still claim settlement.
            deal(stableCoinToken, redeemer, 123e6);
            vm.prank(newAccount);
            gateway.claim(_toArray(redeemer));
            assertEq(IERC20(stableCoinToken).balanceOf(newAccount), 123e6);
        }

        /// @notice U:[SRG-7A]: transferRedeemer reverts when new account is not registered
        function test_U_SRG_07A_transferRedeemer_reverts_when_new_account_not_registered() public {
            deal(dsToken, account, 100e18);
            vm.prank(account);
            IERC20(dsToken).approve(address(gateway), 100e18);
            vm.prank(account);
            gateway.redeem(100e18, "");

            address redeemer = gateway.getRedeemers(account)[0];
            transferMaster.setTransferAllowed(account);
            address unregisteredAccount = makeAddr("UNREGISTERED_ACCOUNT");

            vm.expectRevert(ISecuritizeRedemptionGateway.NewAccountNotRegisteredException.selector);
            vm.prank(account);
            gateway.transferRedeemer(redeemer, unregisteredAccount);
        }

        /// @notice U:[SRG-8]: transferRedeemer reverts when transfer is not allowed
        function test_U_SRG_08_transferRedeemer_reverts_when_not_allowed() public {
            deal(dsToken, account, 100e18);
            vm.prank(account);
            IERC20(dsToken).approve(address(gateway), 100e18);
            vm.prank(account);
            gateway.redeem(100e18, "");

            address redeemer = gateway.getRedeemers(account)[0];
            transferMaster.setTransferAllowed(address(0));

            vm.expectRevert(ISecuritizeRedemptionGateway.RedeemerTransferNotAllowedException.selector);
            vm.prank(account);
            gateway.transferRedeemer(redeemer, newAccount);
        }

        /// @notice U:[SRG-8A]: transferRedeemer reverts when a different account is unlocked
        function test_U_SRG_08A_transferRedeemer_reverts_when_other_account_unlocked() public {
            deal(dsToken, account, 100e18);
            vm.prank(account);
            IERC20(dsToken).approve(address(gateway), 100e18);
            vm.prank(account);
            gateway.redeem(100e18, "");

            address redeemer = gateway.getRedeemers(account)[0];
            transferMaster.setTransferAllowed(newAccount);

            vm.expectRevert(ISecuritizeRedemptionGateway.RedeemerTransferNotAllowedException.selector);
            vm.prank(account);
            gateway.transferRedeemer(redeemer, newAccount);
        }

        /// @notice U:[SRG-9]: transferRedeemer reverts when redeemer is not owned
        function test_U_SRG_09_transferRedeemer_reverts_if_not_owned() public {
            transferMaster.setTransferAllowed(account);

            vm.expectRevert(ISecuritizeRedemptionGateway.RedeemerTransferNotAllowedException.selector);
            vm.prank(account);
            gateway.transferRedeemer(makeAddr("UNKNOWN_REDEEMER"), newAccount);
        }

        /// @notice U:[SRG-10]: claim works after transferRedeemer
        function test_U_SRG_10_claim_works_after_transferRedeemer() public {
            deal(dsToken, account, 100e18);
            vm.prank(account);
            IERC20(dsToken).approve(address(gateway), 100e18);

            vm.prank(account);
            gateway.redeem(100e18, "");

            address redeemer = gateway.getRedeemers(account)[0];
            transferMaster.setTransferAllowed(account);

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

        /// @notice U:[SRG-10A]: transferRedeemer can only be used once per redeemer
        function test_U_SRG_10A_transferRedeemer_can_only_be_used_once() public {
            deal(dsToken, account, 100e18);
            vm.prank(account);
            IERC20(dsToken).approve(address(gateway), 100e18);
            vm.prank(account);
            gateway.redeem(100e18, "");

            address redeemer = gateway.getRedeemers(account)[0];
            transferMaster.setTransferAllowed(account);

            vm.prank(account);
            gateway.transferRedeemer(redeemer, newAccount);

            transferMaster.setTransferAllowed(newAccount);
            vm.expectRevert(ISecuritizeRedemptionGateway.RedeemerTransferNotAllowedException.selector);
            vm.prank(newAccount);
            gateway.transferRedeemer(redeemer, account);
        }

        /// @notice U:[SRG-11]: redeem reverts when max unclaimed redeemers is reached
        function test_U_SRG_11_redeem_reverts_on_max_unclaimed_redeemers() public {
            deal(dsToken, account, 11e18);
            vm.startPrank(account);
            IERC20(dsToken).approve(address(gateway), 11e18);
            for (uint256 i = 0; i < 10; ++i) {
                gateway.redeem(1e18, "");
            }
            vm.expectRevert(ISecuritizeRedemptionGateway.MaxUnclaimedRedeemersPerAccountException.selector);
            gateway.redeem(1e18, "");
            vm.stopPrank();
        }

        /// @notice U:[SRG-12]: `redeem` logs redemption when logger is configured
        function test_U_SRG_12_redeem_logs_when_logger_configured() public {
            RedemptionLogger logger = new RedemptionLogger(address(this));
            RedemptionLoggerAddressProviderMock loggerAddressProvider =
                new RedemptionLoggerAddressProviderMock(address(logger));
            SecuritizeRedemptionGateway gatewayWithLogger = new SecuritizeRedemptionGateway(
                dsToken,
                stableCoinToken,
                redemptionAccount,
                address(whitelister),
                address(transferMaster),
                address(navProvider),
                address(registryService),
                address(loggerAddressProvider)
            );
            logger.setGatewayAllowed(address(gatewayWithLogger), true);

            deal(dsToken, account, 100e18);
            vm.prank(account);
            IERC20(dsToken).approve(address(gatewayWithLogger), 100e18);

            bytes memory extraData = abi.encode(uint256(42));
            vm.prank(account);
            gatewayWithLogger.redeem(100e18, extraData);

            address redeemer = gatewayWithLogger.getRedeemers(account)[0];
            IRedemptionLogger.RedemptionLog memory log = logger.redemptionLogs(redeemer);
            assertEq(log.creditAccount, account, "Incorrect logged credit account");
            assertEq(log.redeemer, redeemer, "Incorrect logged redeemer");
            assertEq(log.extraData, extraData, "Incorrect logged extraData");
        }

        function _toArray(address value) internal pure returns (address[] memory arr) {
            arr = new address[](1);
            arr[0] = value;
        }
    }
