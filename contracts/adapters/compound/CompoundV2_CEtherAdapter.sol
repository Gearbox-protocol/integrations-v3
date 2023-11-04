// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {CEtherGateway} from "../../helpers/compound/CompoundV2_CEtherGateway.sol";
import {CompoundV2_CTokenAdapter} from "./CompoundV2_CTokenAdapter.sol";
import {ICEther} from "../../integrations/compound/ICEther.sol";
import {ICompoundV2_CTokenAdapter} from "../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";

/// @title Compound V2 CEther adapter
contract CompoundV2_CEtherAdapter is CompoundV2_CTokenAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.COMPOUND_V2_CETHER;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice cETH token address
    address public immutable override cToken;

    /// @notice WETH token address
    address public immutable override underlying;

    /// @notice Collateral token mask of WETH in the credit manager
    uint256 public immutable override tokenMask;

    /// @notice Collateral token mask of cETH in the credit manager
    uint256 public immutable override cTokenMask;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _cethGateway CEther gateway contract address
    constructor(address _creditManager, address _cethGateway)
        CompoundV2_CTokenAdapter(_creditManager, _cethGateway) // U:[COMP2E-1]
    {
        cToken = CEtherGateway(payable(targetContract)).ceth(); // U:[COMP2E-1]
        underlying = CEtherGateway(payable(targetContract)).weth(); // U:[COMP2E-1]

        cTokenMask = _getMaskOrRevert(cToken); // U:[COMP2E-1]
        tokenMask = _getMaskOrRevert(underlying); // U:[COMP2E-1]
    }

    /// @dev Internal implementation of `mint`
    ///      - WETH is approved before the call because Gateway needs permission to transfer it
    ///      - cETH is enabled after the call
    ///      - WETH is not disabled after the call because operation doesn't spend the entire balance
    function _mint(uint256 amount)
        internal
        override
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error)
    {
        _approveToken(underlying, type(uint256).max); // U:[COMP2E-4]
        error = abi.decode(_execute(_encodeMint(amount)), (uint256)); // U:[COMP2E-4]
        _approveToken(underlying, 1); // U:[COMP2E-4]
        (tokensToEnable, tokensToDisable) = (cTokenMask, 0);
    }

    /// @dev Internal implementation of `mintDiff`
    ///      - WETH is approved before the call because Gateway needs permission to transfer it
    ///      - cETH is enabled after the call
    ///      - WETH is disabled after the call if leftoverAmount <= 1
    function _mintDiff(uint256 leftoverAmount)
        internal
        override
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error)
    {
        address creditAccount = _creditAccount(); // U:[COMP2E-5]

        uint256 amount = IERC20(underlying).balanceOf(creditAccount); // U:[COMP2E-5]
        if (amount <= leftoverAmount) return (0, 0, 0);
        unchecked {
            amount -= leftoverAmount; // U:[COMP2E-5]
        }

        _approveToken(underlying, type(uint256).max); // U:[COMP2E-5]
        error = abi.decode(_execute(_encodeMint(amount)), (uint256)); // U:[COMP2E-5]
        _approveToken(underlying, 1); // U:[COMP2E-5]
        (tokensToEnable, tokensToDisable) = (cTokenMask, leftoverAmount <= 1 ? tokenMask : 0);
    }

    /// @dev Internal implementation of `redeem`
    ///      - cETH is approved before the call because Gateway needs permission to transfer it
    ///      - WETH is enabled after the call
    ///      - cETH is not disabled after the call because operation doesn't spend the entire balance
    function _redeem(uint256 amount)
        internal
        override
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error)
    {
        _approveToken(cToken, type(uint256).max); // U:[COMP2E-6]
        error = abi.decode(_execute(_encodeRedeem(amount)), (uint256)); // U:[COMP2E-6]
        _approveToken(cToken, 1); // U:[COMP2E-6]
        (tokensToEnable, tokensToDisable) = (tokenMask, 0);
    }

    /// @dev Internal implementation of `redeemDiff`
    ///      - cETH is approved before the call because Gateway needs permission to transfer it
    ///      - WETH is enabled after the call
    ///      - cETH is disabled after the call if leftoverAmount <= 1
    function _redeemDiff(uint256 leftoverAmount)
        internal
        override
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error)
    {
        address creditAccount = _creditAccount(); // U:[COMP2E-7]

        uint256 amount = ICEther(cToken).balanceOf(creditAccount); // U:[COMP2E-7]
        if (amount <= leftoverAmount) return (0, 0, 0);
        unchecked {
            amount -= leftoverAmount; // U:[COMP2E-7]
        }

        _approveToken(cToken, type(uint256).max); // U:[COMP2E-7]
        error = abi.decode(_execute(_encodeRedeem(amount)), (uint256)); // U:[COMP2E-7]
        _approveToken(cToken, 1); // U:[COMP2E-7]
        (tokensToEnable, tokensToDisable) = (tokenMask, leftoverAmount <= 1 ? cTokenMask : 0);
    }

    /// @dev Internal implementation of `redeemUnderlying`
    ///      - cETH is approved before the call because Gateway needs permission to transfer it
    ///      - WETH is enabled after the call
    ///      - cETH is not disabled after the call because operation doesn't spend the entire balance
    function _redeemUnderlying(uint256 amount)
        internal
        override
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error)
    {
        _approveToken(cToken, type(uint256).max); // U:[COMP2E-8]
        error = abi.decode(_execute(_encodeRedeemUnderlying(amount)), (uint256)); // U:[COMP2E-8]
        _approveToken(cToken, 1); // U:[COMP2E-8]
        (tokensToEnable, tokensToDisable) = (tokenMask, 0);
    }
}
