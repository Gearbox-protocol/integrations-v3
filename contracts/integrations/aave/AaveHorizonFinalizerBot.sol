// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBot} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IBot.sol";
import {IStateSerializer} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IStateSerializer.sol";
import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {ICreditFacadeV3, MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {
    DECREASE_DEBT_PERMISSION,
    EXTERNAL_CALLS_PERMISSION,
    ICreditFacadeV3Multicall,
    UPDATE_QUOTA_PERMISSION,
    WITHDRAW_COLLATERAL_PERMISSION
} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {
    CollateralCalcTask,
    CollateralDebtData,
    ICreditManagerV3
} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {
    AmountCantBeZeroException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ReentrancyGuardTrait} from "@gearbox-protocol/core-v3/contracts/traits/ReentrancyGuardTrait.sol";

import {IAaveHorizonBridgeAdapter} from "./interfaces/IAaveHorizonBridgeAdapter.sol";
import {IAaveHorizonFinalizerBot} from "./interfaces/IAaveHorizonFinalizerBot.sol";
import {IAaveV3Pool} from "./interfaces/external/IAaveV3Pool.sol";
import {IAaveV3PoolAdapter} from "./interfaces/IAaveV3PoolAdapter.sol";

/// @title Aave Horizon Finalizer Bot
/// @notice Finalizes open/close of Horizon-backed Gearbox positions via `botMulticall`
contract AaveHorizonFinalizerBot is IAaveHorizonFinalizerBot, ReentrancyGuardTrait {
    /// @inheritdoc IVersion
    uint256 public constant override version = 3_11;

    /// @inheritdoc IVersion
    bytes32 public constant override contractType = "BOT::AAVE_HORIZON_FINALIZER";

    /// @inheritdoc IBot
    uint192 public constant override requiredPermissions =
        EXTERNAL_CALLS_PERMISSION | DECREASE_DEBT_PERMISSION | WITHDRAW_COLLATERAL_PERMISSION | UPDATE_QUOTA_PERMISSION;

    /// @inheritdoc IAaveHorizonFinalizerBot
    address public immutable override pool;

    /// @inheritdoc IAaveHorizonFinalizerBot
    address public immutable override bridge;

    /// @notice Constructor
    /// @param pool_ Horizon Aave V3 Pool
    /// @param bridge_ Aave Horizon Bridge
    constructor(address pool_, address bridge_) {
        if (pool_ == address(0) || bridge_ == address(0)) revert ZeroAddressException();
        pool = pool_;
        bridge = bridge_;
    }

    /// @inheritdoc IStateSerializer
    function serialize() external view override returns (bytes memory) {
        return abi.encode(pool, bridge);
    }

    /// @inheritdoc IAaveHorizonFinalizerBot
    function finalizeOpen(
        address creditAccount,
        address rwaToken,
        MultiCall calldata claimCall,
        address depositPhantomToken
    ) external override nonReentrant {
        _validateClaimAndPhantom(claimCall, depositPhantomToken);

        address creditManager = ICreditAccountV3(creditAccount).creditManager();

        uint256 totalDebt = _getTotalDebt(creditManager, creditAccount);
        if (totalDebt == 0) revert AmountCantBeZeroException();

        bool hasClaim = !_isClaimEmpty(claimCall);
        if (!hasClaim && IERC20(rwaToken).balanceOf(creditAccount) == 0) revert AmountCantBeZeroException();

        MultiCall[] memory calls =
            _buildFinalizeOpenCalls(creditManager, rwaToken, claimCall, depositPhantomToken, totalDebt, hasClaim);

        ICreditFacadeV3(ICreditManagerV3(creditManager).creditFacade()).botMulticall(creditAccount, calls);
    }

    /// @inheritdoc IAaveHorizonFinalizerBot
    function finalizeClose(address creditAccount, MultiCall calldata claimCall, address withdrawPhantomToken)
        external
        override
        nonReentrant
    {
        _validateClaimAndPhantom(claimCall, withdrawPhantomToken);

        address creditManager = ICreditAccountV3(creditAccount).creditManager();
        address creditFacade = ICreditManagerV3(creditManager).creditFacade();
        address underlying = ICreditManagerV3(creditManager).underlying();
        address owner = _getOwner(creditManager, creditAccount);

        bool hasClaim = !_isClaimEmpty(claimCall);
        bool hasPhantom = withdrawPhantomToken != address(0);

        uint256 callCount = 2; // decreaseDebt + withdrawCollateral
        if (hasClaim) ++callCount;
        if (hasPhantom) ++callCount;

        MultiCall[] memory calls = new MultiCall[](callCount);
        uint256 i;

        if (hasClaim) {
            calls[i++] = claimCall;
        }

        if (hasPhantom) {
            calls[i++] = MultiCall({
                target: creditFacade,
                callData: abi.encodeCall(
                    ICreditFacadeV3Multicall.updateQuota, (withdrawPhantomToken, type(int96).min, 0)
                )
            });
        }

        calls[i++] = MultiCall({
            target: creditFacade, callData: abi.encodeCall(ICreditFacadeV3Multicall.decreaseDebt, (type(uint256).max))
        });

        calls[i] = MultiCall({
            target: creditFacade,
            callData: abi.encodeCall(
                ICreditFacadeV3Multicall.withdrawCollateral, (underlying, type(uint256).max, owner)
            )
        });

        ICreditFacadeV3(creditFacade).botMulticall(creditAccount, calls);
    }

    // --------- //
    // INTERNALS //
    // --------- //

    function _buildFinalizeOpenCalls(
        address creditManager,
        address rwaToken,
        MultiCall calldata claimCall,
        address depositPhantomToken,
        uint256 totalDebt,
        bool hasClaim
    ) internal view returns (MultiCall[] memory calls) {
        address creditFacade = ICreditManagerV3(creditManager).creditFacade();
        address underlying = ICreditManagerV3(creditManager).underlying();

        address poolAdapter = ICreditManagerV3(creditManager).contractToAdapter(pool);
        address bridgeAdapter = ICreditManagerV3(creditManager).contractToAdapter(bridge);
        if (poolAdapter == address(0) || bridgeAdapter == address(0)) revert AdapterNotFoundException();

        address aToken = IAaveV3Pool(pool).getReserveAToken(rwaToken);
        address quotedToken = depositPhantomToken != address(0) ? depositPhantomToken : rwaToken;

        calls = new MultiCall[](hasClaim ? 5 : 4);
        uint256 i;

        if (hasClaim) {
            calls[i++] = claimCall;
        }

        // Supply entire RWA balance (after optional claim) into Horizon
        calls[i++] =
            MultiCall({target: poolAdapter, callData: abi.encodeCall(IAaveV3PoolAdapter.supplyDiff, (rwaToken, 0))});

        // Move all resulting aTokens to the owner and borrow full CA debt
        calls[i++] = MultiCall({
            target: bridgeAdapter,
            callData: abi.encodeCall(IAaveHorizonBridgeAdapter.openPositionDiff, (aToken, underlying, 0, totalDebt))
        });

        calls[i++] = MultiCall({
            target: creditFacade,
            callData: abi.encodeCall(ICreditFacadeV3Multicall.updateQuota, (quotedToken, type(int96).min, 0))
        });

        calls[i] = MultiCall({
            target: creditFacade, callData: abi.encodeCall(ICreditFacadeV3Multicall.decreaseDebt, (type(uint256).max))
        });
    }

    function _isClaimEmpty(MultiCall calldata claimCall) internal pure returns (bool) {
        return claimCall.target == address(0) && claimCall.callData.length == 0;
    }

    function _validateClaimAndPhantom(MultiCall calldata claimCall, address phantom) internal pure {
        bool hasClaim = !_isClaimEmpty(claimCall);
        if (hasClaim != (phantom != address(0))) revert InvalidClaimPhantomPairException();
    }

    function _getTotalDebt(address creditManager, address creditAccount) internal view returns (uint256) {
        CollateralDebtData memory cdd =
            ICreditManagerV3(creditManager).calcDebtAndCollateral(creditAccount, CollateralCalcTask.DEBT_ONLY);
        return cdd.debt + cdd.accruedInterest + cdd.accruedFees;
    }

    function _getOwner(address creditManager, address creditAccount) internal view returns (address owner) {
        (,,,,,,, owner) = ICreditManagerV3(creditManager).creditAccountInfo(creditAccount);
    }
}
