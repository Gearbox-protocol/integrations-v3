// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MidasDecimals} from "./MidasDecimals.sol";
import {IMidasDepositVault, DepositStatus} from "./interfaces/external/IMidasDepositVault.sol";
import {IMidasDataFeed} from "./interfaces/external/IMidasDataFeed.sol";

/// @title Midas depositor
/// @notice Holds exactly one Midas deposit request on behalf of an account
/// @dev Deployed as a minimal clone by the gateway, one per request, so that requests settle and can be
///      transferred independently. All state changes go through the gateway.
contract MidasDepositor {
    using SafeERC20 for IERC20;

    /// @notice Thrown when attempting to call a function from a caller other than the gateway.
    error CallerNotGatewayException();

    /// @notice Thrown when attempting to request a deposit from a used depositor
    error AlreadyRequestedException();

    /// @notice Thrown when attempting to withdraw more tokens than the depositor has
    error InsufficientBalanceException();

    /// @notice The account connected to this depositor
    address public account;

    /// @notice The gateway that is using this depositor
    address public immutable gateway;

    /// @notice The mToken deposit vault
    address public immutable midasDepositVault;

    /// @notice The data feed for the mToken
    address public immutable mTokenDataFeed;

    /// @notice Address of the mToken
    address public immutable mToken;

    /// @notice Address of the payment token deposited into Midas
    address public immutable tokenIn;

    /// @notice Referrer ID used for deposits
    bytes32 public immutable referrerId;

    /// @notice The request ID for the deposit request
    uint256 public requestId;

    /// @notice Whether this depositor already submitted a deposit request
    bool public alreadyRequested;

    /// @notice The timestamp when the deposit request was started
    uint256 public depositStartTimestamp;

    modifier whenNotAlreadyRequested() {
        if (alreadyRequested) revert AlreadyRequestedException();
        _;
    }

    modifier gatewayOnly() {
        if (msg.sender != gateway) revert CallerNotGatewayException();
        _;
    }

    /// @notice Constructor
    /// @param _midasDepositVault Address of the Midas Deposit Vault
    /// @param _tokenIn Address of the payment token deposited into Midas
    /// @param _referrerId Referrer ID used for deposits
    /// @param _priceDepositsByCurrentRate Whether to price pending deposits by the live mToken rate
    constructor(address _midasDepositVault, address _tokenIn, bytes32 _referrerId, bool _priceDepositsByCurrentRate) {
        gateway = msg.sender;
        midasDepositVault = _midasDepositVault;
        mToken = IMidasDepositVault(_midasDepositVault).mToken();
        mTokenDataFeed =
            _priceDepositsByCurrentRate ? IMidasDepositVault(_midasDepositVault).mTokenDataFeed() : address(0);
        tokenIn = _tokenIn;
        referrerId = _referrerId;
    }

    /// @notice Sets the account for this depositor
    function setAccount(address _account) external gatewayOnly {
        account = _account;
    }

    /// @notice Requests a deposit of payment token for mToken
    /// @param amountTokenIn Amount of payment token to deposit (native decimals)
    /// @dev One-shot: `requestId` identifies the single request this clone tracks and must never be overwritten
    function requestDeposit(uint256 amountTokenIn) external gatewayOnly whenNotAlreadyRequested {
        uint256 amountTokenE18 = MidasDecimals.toE18(tokenIn, amountTokenIn);
        IERC20(tokenIn).forceApprove(midasDepositVault, amountTokenIn);
        requestId = IMidasDepositVault(midasDepositVault).depositRequest(tokenIn, amountTokenE18, referrerId);
        alreadyRequested = true;
        depositStartTimestamp = block.timestamp;
        _sweepTokenIn();
    }

    /// @notice Requests a deposit with a non-zero instant share
    /// @param amountTokenIn Amount of payment token to deposit (native decimals)
    /// @param instantShare Fraction (in bp) of the amount to deposit instantly
    /// @param minReceiveAmountInstantShare Minimum amount of mToken to receive for the instant share
    /// @dev Instant share is minted directly to `account`; delayed share recipient is this depositor
    function requestDepositHybrid(uint256 amountTokenIn, uint256 instantShare, uint256 minReceiveAmountInstantShare)
        external
        gatewayOnly
        whenNotAlreadyRequested
    {
        uint256 amountTokenE18 = MidasDecimals.toE18(tokenIn, amountTokenIn);
        IERC20(tokenIn).forceApprove(midasDepositVault, amountTokenIn);
        (requestId,) = IMidasDepositVault(midasDepositVault)
            .depositRequest(
                tokenIn, amountTokenE18, referrerId, address(this), instantShare, minReceiveAmountInstantShare, account
            );
        alreadyRequested = true;
        depositStartTimestamp = block.timestamp;
        _sweepTokenIn();
    }

    /// @notice Withdraws minted mToken to the connected account
    /// @param amount Amount of mToken to withdraw
    /// @dev Also sweeps any leftover payment token, in case Midas leaves residual for some reason
    function withdraw(uint256 amount) external gatewayOnly {
        if (amount != 0) {
            if (IERC20(mToken).balanceOf(address(this)) < amount) revert InsufficientBalanceException();
            IERC20(mToken).safeTransfer(account, amount);
        }
        _sweepTokenIn();
    }

    /// @notice Returns the expected amount of mToken for the pending deposit request
    /// @dev Drops to zero as soon as Midas approves or rejects the request. On approval the value reappears as a
    ///      claimable mToken balance; on rejection Midas returns nothing.
    /// @dev Uses the live mToken data feed when configured (`_priceDepositsByCurrentRate`), otherwise the initial
    ///      `tokenOutRate` from the request.
    function pendingTokenOutAmount() external view returns (uint256) {
        (,, DepositStatus status,, uint256 usdAmountWithoutFees, uint256 tokenOutRate,,,) =
            IMidasDepositVault(midasDepositVault).mintRequests(requestId);

        if (status != DepositStatus.PENDING) return 0;

        uint256 mTokenRate = tokenOutRate;
        if (mTokenDataFeed != address(0)) {
            mTokenRate = IMidasDataFeed(mTokenDataFeed).getDataInBase18();
        }

        if (mTokenRate == 0) return 0;
        return (usdAmountWithoutFees * 1e18) / mTokenRate;
    }

    /// @notice Returns the amount of mToken that can be claimed
    /// @dev Simply the balance: Midas settles by minting mToken here, with no callback to hook into
    function claimableTokenOutAmount() external view returns (uint256) {
        return IERC20(mToken).balanceOf(address(this));
    }

    /// @dev Returns any payment token left here to the account
    function _sweepTokenIn() internal {
        uint256 tokenInBalance = IERC20(tokenIn).balanceOf(address(this));
        if (tokenInBalance > 0) {
            tokenIn.call(abi.encodeCall(IERC20.transfer, (account, tokenInBalance)));
        }
    }
}

