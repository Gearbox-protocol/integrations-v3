// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {
    AmountCantBeZeroException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {OptionalCall} from "@gearbox-protocol/core-v3/contracts/libraries/OptionalCall.sol";
import {ReentrancyGuardTrait} from "@gearbox-protocol/core-v3/contracts/traits/ReentrancyGuardTrait.sol";

import {CACheckerTrait} from "../common/CACheckerTrait.sol";
import {IAaveHorizonBridge} from "./interfaces/IAaveHorizonBridge.sol";
import {IAaveV3Pool} from "./interfaces/external/IAaveV3Pool.sol";
import {IInvestorAware} from "./interfaces/external/IInvestorAware.sol";
import {IRwaATokenManager} from "./interfaces/external/IRwaATokenManager.sol";

/// @title Aave Horizon Bridge
/// @notice Moves RWA aTokens between a Credit Account and its economic owner, and borrows/repays on that owner's
///         Horizon position
/// @dev Intended flow:
///      - Open: CA supplies RWA via `AaveV3PoolAdapter` (aTokens minted to the CA), then calls `openPosition` to move
///        aTokens to the owner and borrow into the CA.
///      - Close: CA calls `closePosition` to repay and receive aTokens back, then withdraws via `AaveV3PoolAdapter`.
/// @dev Trust model:
///      - The bridge holds the per-aToken authorized-transfer role on `RwaATokenManager`, so it can move RWA aTokens
///        between the CA and the owner without ERC-20 approval.
///      - The economic owner has delegated borrow allowance on the relevant VariableDebtToken to this bridge.
///      - Horizon debt and aToken collateral sit on the **economic owner** after `openPosition`. Gearbox does not
///        track that Aave position; this contract only moves aTokens and debt funds.
///      - If the CM borrower exposes `getInvestor()` (e.g. SecuritizeWallet), that address is used as the owner.
contract AaveHorizonBridge is ReentrancyGuardTrait, CACheckerTrait, IAaveHorizonBridge {
    using SafeERC20 for IERC20;

    /// @dev Aave V3 variable interest rate mode (stable mode is deprecated)
    uint256 internal constant INTEREST_RATE_MODE_VARIABLE = 2;

    bytes32 public constant override contractType = "GATEWAY::AAVE_HORIZON_BRIDGE";
    uint256 public constant override version = 3_11;

    /// @inheritdoc IAaveHorizonBridge
    address public immutable override pool;

    /// @inheritdoc IAaveHorizonBridge
    address public immutable override rwaATokenManager;

    /// @inheritdoc IAaveHorizonBridge
    uint16 public immutable override referralCode;

    /// @notice Constructor
    /// @param pool_ Aave V3 Horizon Pool
    /// @param rwaATokenManager_ Aave Horizon RWA aToken manager
    /// @param referralCode_ Integrator referral code passed to Aave `borrow`
    /// @param allowedMarketConfigurator_ Market configurator whose credit accounts may call this bridge
    constructor(address pool_, address rwaATokenManager_, uint16 referralCode_, address allowedMarketConfigurator_)
        CACheckerTrait(allowedMarketConfigurator_)
    {
        if (pool_ == address(0) || rwaATokenManager_ == address(0)) revert ZeroAddressException();

        pool = pool_;
        rwaATokenManager = rwaATokenManager_;
        referralCode = referralCode_;
    }

    /// @inheritdoc IAaveHorizonBridge
    function openPosition(address aToken, address debtToken, uint256 aTokenAmount, uint256 borrowAmount)
        external
        override
        nonReentrant
        onlyEligibleAccount
    {
        if (aTokenAmount == 0 || borrowAmount == 0) revert AmountCantBeZeroException();

        address owner = _getOwner(msg.sender);

        IRwaATokenManager(rwaATokenManager).transferRwaAToken(aToken, msg.sender, owner, aTokenAmount);

        IAaveV3Pool(pool).borrow(debtToken, borrowAmount, INTEREST_RATE_MODE_VARIABLE, referralCode, owner);
        IERC20(debtToken).safeTransfer(msg.sender, borrowAmount);
    }

    /// @inheritdoc IAaveHorizonBridge
    function closePosition(address aToken, address debtToken, uint256 repayAmount, uint256 aTokenAmount)
        external
        override
        nonReentrant
        onlyEligibleAccount
    {
        if (repayAmount == 0 || aTokenAmount == 0) revert AmountCantBeZeroException();

        address owner = _getOwner(msg.sender);

        IERC20(debtToken).safeTransferFrom(msg.sender, address(this), repayAmount);
        IERC20(debtToken).forceApprove(pool, repayAmount);
        IAaveV3Pool(pool).repay(debtToken, repayAmount, INTEREST_RATE_MODE_VARIABLE, owner);
        IERC20(debtToken).forceApprove(pool, 0);

        IRwaATokenManager(rwaATokenManager).transferRwaAToken(aToken, owner, msg.sender, aTokenAmount);
    }

    /// @dev Resolves the economic owner: CM borrower, or `getInvestor()` when the borrower exposes it
    function _getOwner(address creditAccount) internal view returns (address owner) {
        address creditManager = ICreditAccountV3(creditAccount).creditManager();
        (,,,,,,, owner) = ICreditManagerV3(creditManager).creditAccountInfo(creditAccount);

        (bool success, bytes memory returnData) = OptionalCall.staticCallOptionalSafe({
            target: owner, data: abi.encodeCall(IInvestorAware.getInvestor, ()), gasAllowance: 50_000
        });
        if (success) {
            address investor = abi.decode(returnData, (address));
            if (investor != address(0)) owner = investor;
        }
    }
}
