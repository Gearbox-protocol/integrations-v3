// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import {CEtherGateway} from "./CEtherGateway.sol";
import {CompoundV2_CTokenAdapter} from "./CompoundV2_CTokenAdapter.sol";
import {ICEther} from "../../integrations/compound/ICEther.sol";

/// @title Compound V2 CEther adapter
contract CompoundV2_CEtherAdapter is CompoundV2_CTokenAdapter {
    /// @notice cToken that this adapter is connected to
    address public immutable override cToken;

    /// @notice cToken's underlying token
    address public immutable override underlying;

    /// @notice Collateral token mask of underlying token in the credit manager
    uint256 public immutable override tokenMask;

    /// @notice Collateral token mask of cToken in the credit manager
    uint256 public immutable override cTokenMask;

    AdapterType public constant override _gearboxAdapterType = AdapterType.COMPOUND_V2_CETHER;
    uint16 public constant override _gearboxAdapterVersion = 1;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _cethGateway CEther gateway contract address
    constructor(address _creditManager, address _cethGateway) CompoundV2_CTokenAdapter(_creditManager, _cethGateway) {
        cToken = address(CEtherGateway(payable(targetContract)).ceth());
        underlying = address(CEtherGateway(payable(targetContract)).weth());

        cTokenMask = creditManager.tokenMasksMap(cToken);
        if (cTokenMask == 0) {
            revert TokenIsNotInAllowedList(cToken);
        }

        tokenMask = creditManager.tokenMasksMap(underlying);
        if (tokenMask == 0) {
            revert TokenIsNotInAllowedList(underlying);
        }
    }

    /// -------------------------------- ///
    /// VIRTUAL FUNCTIONS IMPLEMENTATION ///
    /// -------------------------------- ///

    /// @dev Internal implementation of `mint`
    ///      - WETH is approved before the call because Gateway needs permission to transfer it
    ///      - cETH is enabled after the call
    ///      - WETH is not disabled after the call because operation doesn't spend the entire balance
    function _mint(uint256 amount) internal override returns (uint256 error) {
        _approveToken(underlying, type(uint256).max);
        error = abi.decode(_execute(_encodeMint(amount)), (uint256));
        _approveToken(underlying, 1);
        _changeEnabledTokens(cTokenMask, 0);
    }

    /// @dev Internal implementation of `mintAll`
    ///      - WETH is approved before the call because Gateway needs permission to transfer it
    ///      - cETH is enabled after the call
    ///      - WETH is disabled after the call because operation spends the entire balance
    function _mintAll() internal override returns (uint256 error) {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(underlying).balanceOf(creditAccount);
        if (balance <= 1) return 0;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }

        _approveToken(underlying, type(uint256).max);
        error = abi.decode(_execute(_encodeMint(amount)), (uint256));
        _approveToken(underlying, 1);
        _changeEnabledTokens(cTokenMask, tokenMask);
    }

    /// @dev Internal implementation of `redeem`
    ///      - cETH is approved before the call because Gateway needs permission to transfer it
    ///      - WETH is enabled after the call
    ///      - cETH is not disabled after the call because operation doesn't spend the entire balance
    function _redeem(uint256 amount) internal override returns (uint256 error) {
        _approveToken(cToken, type(uint256).max);
        error = abi.decode(_execute(_encodeRedeem(amount)), (uint256));
        _approveToken(cToken, 1);
        _changeEnabledTokens(tokenMask, 0);
    }

    /// @dev Internal implementation of `redeemAll`
    ///      - cETH is approved before the call because Gateway needs permission to transfer it
    ///      - WETH is enabled after the call
    ///      - cETH is disabled after the call because operation spends the entire balance
    function _redeemAll() internal override returns (uint256 error) {
        address creditAccount = _creditAccount();
        uint256 balance = ICEther(cToken).balanceOf(creditAccount);
        if (balance <= 1) return 0;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }

        _approveToken(cToken, type(uint256).max);
        error = abi.decode(_execute(_encodeRedeem(amount)), (uint256));
        _approveToken(cToken, 1);
        _changeEnabledTokens(tokenMask, cTokenMask);
    }

    /// @dev Internal implementation of `redeemUnderlying`
    ///      - cETH is approved before the call because Gateway needs permission to transfer it
    ///      - WETH is enabled after the call
    ///      - cETH is not disabled after the call because operation doesn't spend the entire balance
    function _redeemUnderlying(uint256 amount) internal override returns (uint256 error) {
        _approveToken(cToken, type(uint256).max);
        error = abi.decode(_encodeRedeemUnderlying(amount), (uint256));
        _approveToken(cToken, 1);
        _changeEnabledTokens(tokenMask, 0);
    }
}
