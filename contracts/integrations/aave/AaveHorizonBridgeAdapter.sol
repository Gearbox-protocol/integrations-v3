// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {TokenNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AbstractAdapter} from "../common/AbstractAdapter.sol";
import {IAaveHorizonBridge} from "./interfaces/IAaveHorizonBridge.sol";
import {AaveHorizonTokenStatus, IAaveHorizonBridgeAdapter} from "./interfaces/IAaveHorizonBridgeAdapter.sol";

/// @title Aave Horizon Bridge adapter
/// @notice Allows Credit Accounts to open/close Horizon positions via `AaveHorizonBridge`
contract AaveHorizonBridgeAdapter is AbstractAdapter, IAaveHorizonBridgeAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::AAVE_HORIZON_BRIDGE";
    uint256 public constant override version = 3_11;

    /// @inheritdoc IAaveHorizonBridgeAdapter
    address public immutable override bridge;

    /// @dev Allowed RWA aTokens
    EnumerableSet.AddressSet internal _allowedATokens;

    /// @dev Allowed debt tokens
    EnumerableSet.AddressSet internal _allowedDebtTokens;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _bridge Aave Horizon Bridge address
    constructor(address _creditManager, address _bridge) AbstractAdapter(_creditManager, _bridge) {
        bridge = _bridge;
    }

    /// @inheritdoc IAaveHorizonBridgeAdapter
    function openPosition(address aToken, address debtToken, uint256 aTokenAmount, uint256 borrowAmount)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        return _openPosition(aToken, debtToken, aTokenAmount, borrowAmount);
    }

    /// @inheritdoc IAaveHorizonBridgeAdapter
    function openPositionDiff(address aToken, address debtToken, uint256 leftoverAmount, uint256 borrowAmount)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        uint256 balance = IERC20(aToken).balanceOf(_creditAccount());
        if (balance <= leftoverAmount) return false;

        unchecked {
            return _openPosition(aToken, debtToken, balance - leftoverAmount, borrowAmount);
        }
    }

    /// @dev Shared open implementation
    function _openPosition(address aToken, address debtToken, uint256 aTokenAmount, uint256 borrowAmount)
        internal
        returns (bool)
    {
        _validateTokens(aToken, debtToken);

        // aTokens are moved via the bridge's authorized-transfer role; no ERC-20 approval needed
        _execute(abi.encodeCall(IAaveHorizonBridge.openPosition, (aToken, debtToken, aTokenAmount, borrowAmount)));
        return false;
    }

    /// @inheritdoc IAaveHorizonBridgeAdapter
    function closePosition(address aToken, address debtToken, uint256 repayAmount, uint256 aTokenAmount)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        _validateTokens(aToken, debtToken);

        _executeSwapSafeApprove(
            debtToken, abi.encodeCall(IAaveHorizonBridge.closePosition, (aToken, debtToken, repayAmount, aTokenAmount))
        );
        return false;
    }

    // ---- //
    // DATA //
    // ---- //

    /// @inheritdoc IAaveHorizonBridgeAdapter
    function isATokenAllowed(address token) external view override returns (bool) {
        return _allowedATokens.contains(token);
    }

    /// @inheritdoc IAaveHorizonBridgeAdapter
    function isDebtTokenAllowed(address token) external view override returns (bool) {
        return _allowedDebtTokens.contains(token);
    }

    /// @inheritdoc IAaveHorizonBridgeAdapter
    function allowedATokens() public view override returns (address[] memory) {
        return _allowedATokens.values();
    }

    /// @inheritdoc IAaveHorizonBridgeAdapter
    function allowedDebtTokens() public view override returns (address[] memory) {
        return _allowedDebtTokens.values();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, bridge, allowedATokens(), allowedDebtTokens());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @inheritdoc IAaveHorizonBridgeAdapter
    function setATokenStatusBatch(AaveHorizonTokenStatus[] calldata tokens) external override configuratorOnly {
        uint256 len = tokens.length;
        for (uint256 i; i < len; ++i) {
            address token = tokens[i].token;
            if (tokens[i].allowed) {
                _getMaskOrRevert(token);
                _allowedATokens.add(token);
            } else {
                _allowedATokens.remove(token);
            }
            emit SetATokenStatus(token, tokens[i].allowed);
        }
    }

    /// @inheritdoc IAaveHorizonBridgeAdapter
    function setDebtTokenStatusBatch(AaveHorizonTokenStatus[] calldata tokens) external override configuratorOnly {
        uint256 len = tokens.length;
        for (uint256 i; i < len; ++i) {
            address token = tokens[i].token;
            if (tokens[i].allowed) {
                _getMaskOrRevert(token);
                _allowedDebtTokens.add(token);
            } else {
                _allowedDebtTokens.remove(token);
            }
            emit SetDebtTokenStatus(token, tokens[i].allowed);
        }
    }

    /// @dev Ensures both tokens are allowlisted
    function _validateTokens(address aToken, address debtToken) internal view {
        if (!_allowedATokens.contains(aToken) || !_allowedDebtTokens.contains(debtToken)) {
            revert TokenNotAllowedException();
        }
    }
}
