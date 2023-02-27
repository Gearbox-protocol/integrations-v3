// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import {CompoundV2_CTokenAdapter} from "./CompoundV2_CTokenAdapter.sol";
import {ICErc20} from "../../integrations/compound/ICErc20.sol";

/// @title Compound V2 CErc20 adapter
contract CompoundV2_CErc20Adapter is CompoundV2_CTokenAdapter {
    /// @notice cToken's underlying token
    address public immutable override underlying;

    AdapterType public constant _gearboxAdapterType = AdapterType.COMPOUND_V2_CERC20;
    uint16 public constant _gearboxAdapterVersion = 1;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _cToken CErc20 token address
    constructor(address _creditManager, address _cToken) CompoundV2_CTokenAdapter(_creditManager, _cToken) {
        underlying = ICErc20(targetContract).underlying();

        if (creditManager.tokenMasksMap(targetContract) == 0) {
            revert TokenIsNotInAllowedList(targetContract);
        }

        if (creditManager.tokenMasksMap(underlying) == 0) {
            revert TokenIsNotInAllowedList(underlying);
        }
    }

    /// @notice cToken that this adapter is connected to
    function cToken() external view override returns (address) {
        return targetContract;
    }

    /// -------------------------------- ///
    /// VIRTUAL FUNCTIONS IMPLEMENTATION ///
    /// -------------------------------- ///

    /// @dev Internal implementation of `mint`
    ///      - Calls `_executeSwapSafeApprove` because Compound needs permission to transfer underlying
    ///      - `tokenIn` is cToken's underlying token
    ///      - `tokenOut` is cToken
    ///      - `disableTokenIn` is set to false because operation doesn't spend the entire balance
    function _mint(uint256 amount) internal override returns (uint256 error) {
        error = abi.decode(_executeSwapSafeApprove(underlying, targetContract, _encodeMint(amount), false), (uint256));
    }

    /// @dev Internal implementation of `mintAll`
    ///      - Calls `_executeSwapSafeApprove` because Compound needs permission to transfer underlying
    ///      - `tokenIn` is cToken's underlying token
    ///      - `tokenOut` is cToken
    ///      - `disableTokenIn` is set to true because operation spends the entire balance
    function _mintAll() internal override returns (uint256 error) {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(underlying).balanceOf(creditAccount);
        if (balance <= 1) return 0;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }

        error = abi.decode(
            _executeSwapSafeApprove(creditAccount, underlying, targetContract, _encodeMint(amount), true), (uint256)
        );
    }

    /// @dev Internal implementation of `redeem`
    ///      - Calls `_executeSwapNoApprove` because Compound doesn't need permission to burn cTokens
    ///      - `tokenIn` is cToken
    ///      - `tokenOut` is cToken's underlying token
    ///      - `disableTokenIn` is set to false because operation doesn't spend the entire balance
    function _redeem(uint256 amount) internal override returns (uint256 error) {
        error = abi.decode(_executeSwapNoApprove(targetContract, underlying, _encodeRedeem(amount), false), (uint256));
    }

    /// @dev Internal implementation of `redeemAll`
    ///      - Calls `_executeSwapNoApprove` because Compound doesn't need permission to burn cTokens
    ///      - `tokenIn` is cToken
    ///      - `tokenOut` is cToken's underlying token
    ///      - `disableTokenIn` is set to true because operation spends the entire balance
    function _redeemAll() internal override returns (uint256 error) {
        address creditAccount = _creditAccount();
        uint256 balance = ICErc20(targetContract).balanceOf(creditAccount);
        if (balance <= 1) return 0;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }

        error = abi.decode(
            _executeSwapNoApprove(creditAccount, targetContract, underlying, _encodeRedeem(amount), true), (uint256)
        );
    }

    /// @dev Internal implementation of `redeemUnderlying`
    ///      - Calls `_executeSwapNoApprove` because Compound doesn't need permission to burn cTokens
    ///      - `tokenIn` is cToken
    ///      - `tokenOut` is cToken's underlying token
    ///      - `disableTokenIn` is set to false because operation doesn't spend the entire balance
    function _redeemUnderlying(uint256 amount) internal override returns (uint256 error) {
        error = abi.decode(
            _executeSwapNoApprove(targetContract, underlying, _encodeRedeemUnderlying(amount), false), (uint256)
        );
    }
}