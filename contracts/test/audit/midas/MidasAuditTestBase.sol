// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {MidasGateway} from "../../../helpers/midas/MidasGateway.sol";
import {MidasRedeemer} from "../../../helpers/midas/MidasRedeemer.sol";
import {MidasRedemptionVaultPhantomToken} from "../../../helpers/midas/MidasRedemptionVaultPhantomToken.sol";
import {MidasLiquidator} from "../../../helpers/midas/MidasLiquidator.sol";
import {IMidasGateway} from "../../../interfaces/midas/IMidasGateway.sol";
import {IMidasTransferMaster} from "../../../interfaces/midas/IMidasTransferMaster.sol";
import {IRedemptionLogger, AP_REDEMPTION_LOGGER} from "../../../interfaces/IRedemptionLogger.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditFacadeV3, MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IAddressProvider} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAddressProvider.sol";

/// @notice Configurable Midas data feed mock: returns a settable rate in base 18.
contract AuditMidasDataFeed {
    uint256 public rate;
    bool public revertNextCall;

    constructor(uint256 rate_) {
        rate = rate_;
    }

    function setRate(uint256 r) external {
        rate = r;
    }

    function setRevertNextCall(bool v) external {
        revertNextCall = v;
    }

    function getDataInBase18() external view returns (uint256) {
        if (revertNextCall) revert("dataFeed: view unavailable");
        return rate;
    }
}

/// @notice Configurable Midas issuance vault mock.
///         Models: full pull of input, configurable mToken output, optional revert, optional access control.
contract AuditMidasIssuanceVault {
    address public immutable mToken;
    address public accessControl;
    uint256 public mTokenAmountOut;
    bool public revertNextCall;

    constructor(address mToken_) {
        mToken = mToken_;
    }

    function setMTokenAmountOut(uint256 a) external {
        mTokenAmountOut = a;
    }

    function setAccessControl(address ac) external {
        accessControl = ac;
    }

    function setRevertNextCall(bool v) external {
        revertNextCall = v;
    }

    function depositInstant(address tokenIn, uint256 amountTokenE18, uint256, bytes32) external {
        if (revertNextCall) revert("issuance: unavailable");
        uint256 nativeAmount = amountTokenE18 * 10 ** IERC20Metadata(tokenIn).decimals() / 1e18;
        IERC20(tokenIn).transferFrom(msg.sender, address(this), nativeAmount);
        IERC20(mToken).transfer(msg.sender, mTokenAmountOut);
    }
}

/// @notice Configurable Midas redemption vault mock.
///         Models: full pull of mToken on redeemRequest/redeemInstant, configurable output,
///         settable per-request status/rates, optional view reverts, ID starting at 0 (upstream-faithful).
contract AuditMidasRedemptionVault {
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
    bool public redeemRequestsRevert;
    bool public redeemInstantRevert;
    bool public redeemRequestRevert;

    uint256 public currentRequestId;
    mapping(uint256 => Request) internal _requests;

    constructor(address mToken_, address mTokenDataFeed_) {
        mToken = mToken_;
        mTokenDataFeed = mTokenDataFeed_;
    }

    function setTokenOutAmount(uint256 a) external {
        tokenOutAmount = a;
    }

    function setAccessControl(address ac) external {
        accessControl = ac;
    }

    function setRedeemRequestsRevert(bool v) external {
        redeemRequestsRevert = v;
    }

    function setRedeemInstantRevert(bool v) external {
        redeemInstantRevert = v;
    }

    function setRedeemRequestRevert(bool v) external {
        redeemRequestRevert = v;
    }

    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256) external {
        if (redeemInstantRevert) revert("redeemInstant: unavailable");
        IERC20(mToken).transferFrom(msg.sender, address(this), amountMTokenIn);
        IERC20(tokenOut).transfer(msg.sender, tokenOutAmount);
    }

    function redeemRequest(address tokenOut, uint256 amountMTokenIn) external returns (uint256 requestId) {
        if (redeemRequestRevert) revert("redeemRequest: unavailable");
        IERC20(mToken).transferFrom(msg.sender, address(this), amountMTokenIn);
        // Upstream-faithful: first request ID is 0, then increment.
        requestId = currentRequestId;
        _requests[requestId] = Request({
            sender: msg.sender,
            tokenOut: tokenOut,
            status: 0,
            amountMTokenIn: amountMTokenIn,
            mTokenRate: 1e18,
            tokenOutRate: 1e18
        });
        currentRequestId = requestId + 1;
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
        if (redeemRequestsRevert) revert("redeemRequests: view unavailable");
        Request memory r = _requests[requestId];
        return (r.sender, r.tokenOut, r.status, r.amountMTokenIn, r.mTokenRate, r.tokenOutRate);
    }
}

/// @notice Mock credit account exposing the contract type and a settable credit manager.
///         Supports approving tokens so the gateway can pull via transferFrom.
contract AuditCreditAccount {
    bytes32 public constant contractType = "CREDIT_ACCOUNT";
    uint256 public constant version = 3_10;

    address public immutable creditManager;

    constructor(address creditManager_) {
        creditManager = creditManager_;
    }

    function approveToken(address token, address spender, uint256 amount) external {
        IERC20(token).approve(spender, amount);
    }
}

/// @notice Mock that returns a non-credit-account contract type.
contract AuditNonCreditAccount {
    bytes32 public constant contractType = "NOT_CREDIT_ACCOUNT";
}

/// @notice Minimal credit manager mock exposing borrower lookup, contractToAdapter mapping,
///         a settable credit facade address, and a pullFrom helper that simulates the credit
///         manager pulling tokens from a payer using its allowance (as in real addCollateral).
contract AuditCreditManager {
    mapping(address => address) internal _borrowers;
    mapping(address => address) internal _adapterFor;
    address public creditFacade;

    function setBorrower(address creditAccount, address borrower) external {
        _borrowers[creditAccount] = borrower;
    }

    function setAdapter(address target, address adapter) external {
        _adapterFor[target] = adapter;
    }

    function setCreditFacade(address facade) external {
        creditFacade = facade;
    }

    function creditAccountInfo(address creditAccount)
        external
        view
        returns (uint256, uint256, uint128, uint128, uint256, uint16, uint64, address borrower)
    {
        borrower = _borrowers[creditAccount];
        return (0, 0, 0, 0, 0, 0, 0, borrower);
    }

    function contractToAdapter(address target) external view returns (address) {
        return _adapterFor[target];
    }

    /// @dev Simulates the credit manager pulling tokens from `payer` (using its allowance)
    ///      and crediting them to `to`. Mirrors `ICreditManagerV3.addCollateral(payer, ...)`.
    function pullFrom(address payer, address token, uint256 amount, address to) external {
        IERC20(token).transferFrom(payer, to, amount);
    }
}

/// @notice Minimal Midas access control mock supporting role grant/revoke/hasRole.
contract AuditMidasAccessControl {
    mapping(bytes32 => mapping(address => bool)) internal _roles;

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return _roles[role][account];
    }

    function grantRole(bytes32 role, address account) external {
        _roles[role][account] = true;
    }

    function revokeRole(bytes32 role, address account) external {
        _roles[role][account] = false;
    }
}

/// @notice Minimal AddressProvider mock that returns a settable redemption logger address
///         for the AP_REDEMPTION_LOGGER key, mirroring the new gateway constructor behavior.
contract AuditAddressProvider is IAddressProvider {
    address internal _redemptionLogger;

    constructor(address redemptionLogger_) {
        _redemptionLogger = redemptionLogger_;
    }

    function setRedemptionLogger(address logger) external {
        _redemptionLogger = logger;
    }

    function getAddressOrRevert(bytes32 key, uint256 version) external view returns (address) {
        if (key == AP_REDEMPTION_LOGGER && version == 3_10) {
            if (_redemptionLogger == address(0)) revert("AP: redemption logger not set");
            return _redemptionLogger;
        }
        revert("AP: key not found");
    }
}

/// @notice Minimal credit facade mock that records calls and can call back into adapters.
///         Tracks the original multicaller (msg.sender of liquidateCreditAccount) so that
///         addCollateral can pull from the liquidator via the credit manager, mirroring the
///         real Gearbox flow where the facade pulls from the multicaller, not from itself.
contract AuditCreditFacade {
    address public immutable creditManager;
    address[] public addCollateralTokens;
    uint256[] public addCollateralAmounts;
    bool public liquidateRevert;
    address public multicaller;

    constructor(address creditManager_) {
        creditManager = creditManager_;
    }

    function setLiquidateRevert(bool v) external {
        liquidateRevert = v;
    }

    function addCollateral(address token, uint256 amount) external {
        addCollateralTokens.push(token);
        addCollateralAmounts.push(amount);
        // Pull from the tracked multicaller (the liquidator) via the credit manager,
        // which has allowance from the liquidator's forceApprove during _forwardCollateral.
        AuditCreditManager(creditManager).pullFrom(multicaller, token, amount, address(this));
    }

    function liquidateCreditAccount(address, address, MultiCall[] calldata calls, bytes memory) external {
        if (liquidateRevert) revert("facade: liquidation unavailable");
        multicaller = msg.sender;
        for (uint256 i = 0; i < calls.length; i++) {
            (bool ok,) = calls[i].target.call(calls[i].callData);
            if (!ok) revert("facade: multicall step failed");
        }
        multicaller = address(0);
    }

    /// @dev Tolerated no-op selector used to test that _forwardCollateral ignores
    ///      non-addCollateral calls that still target the facade.
    function noop() external {}
}

/// @notice Shared base contract for Midas audit tests.
abstract contract MidasAuditTestBase is Test {
    uint256 internal constant REDEMPTION_DURATION = 1 days;
    bytes32 internal constant REFERRER_ID = bytes32(uint256(0xC0FFEE));

    AuditMidasDataFeed internal dataFeed;
    AuditMidasIssuanceVault internal issuanceVault;
    AuditMidasRedemptionVault internal redemptionVault;
    AuditCreditManager internal creditManager;
    AuditCreditAccount internal account;
    AuditAddressProvider internal addressProvider;
    MidasGateway internal gateway;
    MidasLiquidator internal liquidator;
    MidasRedemptionVaultPhantomToken internal phantomToken;

    address internal mToken;
    address internal quoteToken18;
    address internal borrower;

    function _deployGateway18(bool withDelayedWithdrawals, bool checkBorrowerGreenlist, address accessControl_)
        internal
    {
        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        quoteToken18 = address(new ERC20Mock("DAI", "DAI", 18));
        borrower = makeAddr("BORROWER");

        dataFeed = new AuditMidasDataFeed(1e18);
        issuanceVault = new AuditMidasIssuanceVault(mToken);
        redemptionVault = new AuditMidasRedemptionVault(mToken, address(dataFeed));
        creditManager = new AuditCreditManager();
        // AddressProvider with no redemption logger by default; gateway constructor wraps the
        // lookup in a try/catch so an unset logger yields redemptionLogger = address(0).
        addressProvider = new AuditAddressProvider(address(0));

        if (accessControl_ != address(0)) {
            issuanceVault.setAccessControl(accessControl_);
            redemptionVault.setAccessControl(accessControl_);
        }

        gateway = new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            quoteToken18,
            accessControl_ != address(0),
            address(0),
            checkBorrowerGreenlist,
            REDEMPTION_DURATION,
            withDelayedWithdrawals,
            address(addressProvider)
        );

        liquidator = MidasLiquidator(payable(gateway.transferMaster()));
        if (withDelayedWithdrawals) {
            phantomToken = MidasRedemptionVaultPhantomToken(gateway.phantomToken());
        }

        account = new AuditCreditAccount(address(creditManager));
        creditManager.setBorrower(address(account), borrower);
    }

    /// @dev Sets `isTransferAllowed` on the gateway's liquidator by writing its slot 0.
    function _setTransferAllowed(bool allowed) internal {
        vm.store(address(liquidator), bytes32(uint256(0)), bytes32(uint256(allowed ? 1 : 0)));
    }

    /// @dev Funds the account with `amount` of mToken and approves the gateway to pull it.
    function _fundAccountWithMToken(uint256 amount) internal {
        deal(mToken, address(account), amount);
        vm.prank(address(account));
        account.approveToken(mToken, address(gateway), amount);
    }

    /// @dev Funds the account with `amount` of quote token and approves the gateway to pull it.
    function _fundAccountWithQuote(uint256 amount) internal {
        deal(quoteToken18, address(account), amount);
        vm.prank(address(account));
        account.approveToken(quoteToken18, address(gateway), amount);
    }

    /// @dev Requests a redemption from the account and returns the new redeemer address.
    function _requestRedeemFromAccount(uint256 amountMTokenIn) internal returns (address redeemer) {
        _fundAccountWithMToken(amountMTokenIn);
        vm.prank(address(account));
        gateway.requestRedeem(amountMTokenIn, "");
        redeemer = gateway.pendingRedeemers(address(account))[0];
    }
}
