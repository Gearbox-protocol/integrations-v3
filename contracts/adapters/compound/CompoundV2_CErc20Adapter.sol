// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {CompoundV2_CTokenAdapter} from "./CompoundV2_CTokenAdapter.sol";
import {ICErc20} from "../../integrations/compound/ICErc20.sol";
import {ICompoundV2_CTokenAdapter} from "../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";

/// @title Compound V2 CErc20 adapter
contract CompoundV2_CErc20Adapter is CompoundV2_CTokenAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.COMPOUND_V2_CERC20;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice cToken's underlying token
    address public immutable override underlying;

    /// @notice Collateral token mask of underlying token in the credit manager
    uint256 public immutable override tokenMask;

    /// @notice Collateral token mask of cToken in the credit manager
    uint256 public immutable override cTokenMask;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _cToken CErc20 token address
    constructor(address _creditManager, address _cToken) CompoundV2_CTokenAdapter(_creditManager, _cToken) {
        underlying = ICErc20(targetContract).underlying(); // F: [ACV2CERC-2]

        cTokenMask = _getMaskOrRevert(targetContract); // F: [ACV2CERC-1, ACV2CERC-2]
        tokenMask = _getMaskOrRevert(underlying); // F: [ACV2CERC-2]
    }

    /// @notice cToken that this adapter is connected to
    function cToken() external view override returns (address) {
        return targetContract; // F: [ACV2CERC-2]
    }

    /// @dev Internal implementation of `mint`
    ///      - underlying is approved before the call because cToken needs permission to transfer it
    ///      - cToken is enabled after the call
    ///      - underlying is not disabled after the call because operation doesn't spend the entire balance
    function _mint(uint256 amount)
        internal
        override
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error)
    {
        _approveToken(underlying, type(uint256).max);
        error = abi.decode(_execute(_encodeMint(amount)), (uint256));
        _approveToken(underlying, 1);
        (tokensToEnable, tokensToDisable) = (cTokenMask, 0);
    }

    /// @dev Internal implementation of `mintDiff`
    ///      - underlying is approved before the call because cToken needs permission to transfer it
    ///      - cToken is enabled after the call
    ///      - underlying is disabled after the call if leftoverAmount <= 1
    function _mintDiff(uint256 leftoverAmount)
        internal
        override
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error)
    {
        address creditAccount = _creditAccount();

        uint256 amount = IERC20(underlying).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return (0, 0, 0);
        unchecked {
            amount -= leftoverAmount;
        }

        _approveToken(underlying, type(uint256).max);
        error = abi.decode(_execute(_encodeMint(amount)), (uint256));
        _approveToken(underlying, 1);
        (tokensToEnable, tokensToDisable) = (cTokenMask, leftoverAmount <= 1 ? tokenMask : 0);
    }

    /// @dev Internal implementation of `redeem`
    ///      - cToken is not approved before the call because cToken doesn't need permission to burn it
    ///      - underlying is enabled after the call
    ///      - cToken is not disabled after the call because operation doesn't spend the entire balance
    function _redeem(uint256 amount)
        internal
        override
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error)
    {
        error = abi.decode(_execute(_encodeRedeem(amount)), (uint256));
        (tokensToEnable, tokensToDisable) = (tokenMask, 0);
    }

    /// @dev Internal implementation of `redeemDiff`
    ///      - cToken is not approved before the call because cToken doesn't need permission to burn it
    ///      - underlying is enabled after the call
    ///      - cToken is disabled after the call because operation spends the entire balance
    function _redeemDiff(uint256 leftoverAmount)
        internal
        override
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error)
    {
        address creditAccount = _creditAccount();

        uint256 amount = ICErc20(targetContract).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return (0, 0, 0);
        unchecked {
            amount -= leftoverAmount;
        }

        error = abi.decode(_execute(_encodeRedeem(amount)), (uint256));
        (tokensToEnable, tokensToDisable) = (tokenMask, leftoverAmount <= 1 ? cTokenMask : 0);
    }

    /// @dev Internal implementation of `redeemUnderlying`
    ///      - cToken is not approved before the call because cToken doesn't need permission to burn it
    ///      - underlying is enabled after the call
    ///      - cToken is not disabled after the call because operation doesn't spend the entire balance
    function _redeemUnderlying(uint256 amount)
        internal
        override
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error)
    {
        error = abi.decode(_execute(_encodeRedeemUnderlying(amount)), (uint256));
        (tokensToEnable, tokensToDisable) = (tokenMask, 0);
    }
}
