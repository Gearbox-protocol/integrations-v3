// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasGateway} from "../../../helpers/midas/MidasGateway.sol";

contract PartialSpendMidasDataFeedMock {
    function getDataInBase18() external pure returns (uint256) {
        return 1e18;
    }
}

contract PartialSpendMidasIssuanceVaultMock {
    address public immutable mToken;
    address public accessControl;
    uint256 public immutable spendBps;
    uint256 public mTokenAmountOut;

    constructor(address mToken_, uint256 spendBps_) {
        mToken = mToken_;
        spendBps = spendBps_;
    }

    function setMTokenAmountOut(uint256 amount) external {
        mTokenAmountOut = amount;
    }

    function depositInstant(address tokenIn, uint256 amountToken, uint256, bytes32) external {
        uint256 nativeAmount = amountToken * 10 ** IERC20Metadata(tokenIn).decimals() / 1e18;
        IERC20(tokenIn).transferFrom(msg.sender, address(this), nativeAmount * spendBps / 10_000);
        IERC20(mToken).transfer(msg.sender, mTokenAmountOut);
    }
}

contract PartialSpendMidasRedemptionVaultMock {
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
    uint256 public immutable spendBps;
    uint256 public tokenOutAmount;
    uint256 public currentRequestId;
    mapping(uint256 => Request) internal _requests;

    constructor(address mToken_, address mTokenDataFeed_, uint256 spendBps_) {
        mToken = mToken_;
        mTokenDataFeed = mTokenDataFeed_;
        spendBps = spendBps_;
    }

    function setTokenOutAmount(uint256 amount) external {
        tokenOutAmount = amount;
    }

    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256) external {
        IERC20(mToken).transferFrom(msg.sender, address(this), amountMTokenIn * spendBps / 10_000);
        IERC20(tokenOut).transfer(msg.sender, tokenOutAmount);
    }

    function redeemRequest(address tokenOut, uint256 amountMTokenIn) external returns (uint256 requestId) {
        IERC20(mToken).transferFrom(msg.sender, address(this), amountMTokenIn * spendBps / 10_000);

        requestId = currentRequestId++;
        _requests[requestId] = Request({
            sender: msg.sender,
            tokenOut: tokenOut,
            status: 0,
            amountMTokenIn: amountMTokenIn,
            mTokenRate: 1e18,
            tokenOutRate: 1e18
        });
    }

    function redeemRequests(uint256 requestId)
        external
        view
        returns (address, address, uint8, uint256, uint256, uint256)
    {
        Request memory request = _requests[requestId];
        return (
            request.sender,
            request.tokenOut,
            request.status,
            request.amountMTokenIn,
            request.mTokenRate,
            request.tokenOutRate
        );
    }
}

contract PartialSpendCreditManagerMock {
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

/// @dev Minimal AddressProvider mock returning address(0) for the redemption logger key,
///      mirroring the upstream test helper. Used so the residual-input PoC gateway can be
///      constructed with the new addressProvider parameter without tracking a real logger.
contract PartialSpendAddressProviderMock {
    function getAddressOrRevert(bytes32, uint256) external pure returns (address) {
        return address(0);
    }
}

contract PartialSpendCreditAccountMock {
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

/// @title Midas gateway residual-input security PoCs
/// @notice RED tests for successful Midas calls that consume less input than requested.
contract MidasGatewayResidualsPoCTest is Test {
    uint256 internal constant SPEND_BPS = 6_000;
    uint256 internal constant AMOUNT_IN = 100e18;

    address internal mToken;
    address internal quoteToken;
    PartialSpendMidasIssuanceVaultMock internal issuanceVault;
    PartialSpendMidasRedemptionVaultMock internal redemptionVault;
    PartialSpendCreditManagerMock internal creditManager;
    PartialSpendCreditAccountMock internal account;
    MidasGateway internal gateway;

    function setUp() public {
        mToken = address(new ERC20Mock("mToken", "MT", 18));
        quoteToken = address(new ERC20Mock("Quote", "QUOTE", 18));

        PartialSpendMidasDataFeedMock dataFeed = new PartialSpendMidasDataFeedMock();
        issuanceVault = new PartialSpendMidasIssuanceVaultMock(mToken, SPEND_BPS);
        redemptionVault = new PartialSpendMidasRedemptionVaultMock(mToken, address(dataFeed), SPEND_BPS);
        creditManager = new PartialSpendCreditManagerMock();
        PartialSpendAddressProviderMock addressProvider = new PartialSpendAddressProviderMock();

        gateway = new MidasGateway(
            address(issuanceVault),
            address(redemptionVault),
            quoteToken,
            false,
            address(0),
            false,
            1 days,
            true, // withDelayedWithdrawals
            address(addressProvider)
        );

        account = new PartialSpendCreditAccountMock(address(creditManager));
        creditManager.setBorrower(address(account), makeAddr("BORROWER"));
    }

    /*
     * @test-id: tst_core_midas_015
     * @scenario: scn_midas_partial_input_001
     * @covers: contracts/helpers/midas/MidasGateway.sol::depositInstant
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: MidasGateway with a deterministic partial-spend issuance vault
     * Clients: direct calls
     * Mocks: partial-spend Midas vaults and minimal Credit Account/Credit Manager
     * Data: fixed 60% input spend
     */
    function test_tst_core_midas_015_deposit_refunds_unspent_quote_token() public {
        deal(quoteToken, address(account), AMOUNT_IN);
        account.approveToken(quoteToken, address(gateway), AMOUNT_IN);
        deal(mToken, address(issuanceVault), AMOUNT_IN);
        issuanceVault.setMTokenAmountOut(60e18);

        vm.prank(address(account));
        gateway.depositInstant(AMOUNT_IN, 0, bytes32(0));

        assertEq(IERC20(quoteToken).balanceOf(address(gateway)), 0, "unspent quote token remains in gateway");
    }

    /*
     * @test-id: tst_core_midas_016
     * @scenario: scn_midas_partial_input_002
     * @covers: contracts/helpers/midas/MidasGateway.sol::redeemInstant
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: MidasGateway with a deterministic partial-spend redemption vault
     * Clients: direct calls
     * Mocks: partial-spend Midas vaults and minimal Credit Account/Credit Manager
     * Data: fixed 60% input spend
     */
    function test_tst_core_midas_016_instant_redemption_refunds_unspent_mtoken() public {
        deal(mToken, address(account), AMOUNT_IN);
        account.approveToken(mToken, address(gateway), AMOUNT_IN);
        deal(quoteToken, address(redemptionVault), AMOUNT_IN);
        redemptionVault.setTokenOutAmount(60e18);

        vm.prank(address(account));
        gateway.redeemInstant(AMOUNT_IN, 0);

        assertEq(IERC20(mToken).balanceOf(address(gateway)), 0, "unspent mToken remains in gateway");
    }

    /*
     * @test-id: tst_core_midas_017
     * @scenario: scn_midas_partial_input_003
     * @covers: contracts/helpers/midas/MidasRedeemer.sol::requestRedeem
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: MidasGateway with a deterministic partial-spend redemption vault
     * Clients: direct calls
     * Mocks: partial-spend Midas vaults and minimal Credit Account/Credit Manager
     * Data: fixed 60% input spend
     */
    function test_tst_core_midas_017_delayed_redemption_refunds_unspent_mtoken() public {
        deal(mToken, address(account), AMOUNT_IN);
        account.approveToken(mToken, address(gateway), AMOUNT_IN);

        vm.prank(address(account));
        gateway.requestRedeem(AMOUNT_IN, "");

        address redeemer = gateway.pendingRedeemers(address(account))[0];
        assertEq(IERC20(mToken).balanceOf(redeemer), 0, "unspent mToken remains in redeemer");
    }
}
