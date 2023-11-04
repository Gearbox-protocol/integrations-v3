// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {ICErc20Actions} from "../../integrations/compound/ICErc20.sol";
import {ICompoundV2_CTokenAdapter} from "../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";

/// @title Compound V2 cToken adapter
/// @notice Implements logic allowing CAs to interact with Compound's cTokens
/// @dev Abstract base contract for CErc20 and CEther adapters
abstract contract CompoundV2_CTokenAdapter is AbstractAdapter, ICompoundV2_CTokenAdapter {
    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _targetContract Target contract address, must implement `ICErc20Actions`
    constructor(address _creditManager, address _targetContract)
        AbstractAdapter(_creditManager, _targetContract) // U:[COMP2-1]
    {}

    /// @dev Reverts if CToken operation produced non-zero error code
    function _revertOnError(uint256 error) internal pure {
        if (error != 0) revert CTokenError(error); // U:[COMP2-3]
    }

    // ------- //
    // MINTING //
    // ------- //

    /// @notice Deposit given amount of underlying tokens into Compound in exchange for cTokens
    /// @param amount Amount of underlying tokens to deposit
    function mint(uint256 amount)
        external
        override
        creditFacadeOnly // U:[COMP2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        uint256 error;
        (tokensToEnable, tokensToDisable, error) = _mint(amount); // U:[COMP2-4]
        _revertOnError(error); // U:[COMP2-3]
    }

    /// @notice Deposit all underlying tokens into Compound in exchange for cTokens, except for specified amount
    /// @param leftoverAmount Amount of underlying tokens to keep on the account
    function mintDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[COMP2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        uint256 error;
        (tokensToEnable, tokensToDisable, error) = _mintDiff(leftoverAmount); // U:[COMP2-5]
        _revertOnError(error); // U:[COMP2-3]
    }

    /// @dev Internal implementation of `mint`
    ///      Since minting process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _mint(uint256 amount)
        internal
        virtual
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error);

    /// @dev Internal implementation of `mintDiff`
    ///      Since minting process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _mintDiff(uint256 leftoverAmount)
        internal
        virtual
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error);

    /// @dev Encodes calldata for `ICErc20Actions.mint` call
    function _encodeMint(uint256 amount) internal pure returns (bytes memory callData) {
        callData = abi.encodeCall(ICErc20Actions.mint, (amount)); // U:[COMP2-4,5]
    }

    // --------- //
    // REDEEMING //
    // --------- //

    /// @notice Burn given amount of cTokens to withdraw underlying from Compound
    /// @param amount Amount of cTokens to burn
    function redeem(uint256 amount)
        external
        override
        creditFacadeOnly // U:[COMP2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        uint256 error;
        (tokensToEnable, tokensToDisable, error) = _redeem(amount); // U:[COMP2-6]
        _revertOnError(error); // U:[COMP2-3]
    }

    /// @notice Withdraw all underlying tokens from Compound, except the specified amount, and burn cTokens
    /// @param leftoverAmount Amount of cToken to leave on the account
    function redeemDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[COMP2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        uint256 error;
        (tokensToEnable, tokensToDisable, error) = _redeemDiff(leftoverAmount); // U:[COMP2-7]
        _revertOnError(error); // U:[COMP2-3]
    }

    /// @dev Internal implementation of `redeem`
    ///      Since redeeming process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _redeem(uint256 amount)
        internal
        virtual
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error);

    /// @dev Internal implementation of `redeemDiff`
    ///      Since redeeming process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _redeemDiff(uint256 leftoverAmount)
        internal
        virtual
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error);

    /// @dev Encodes calldata for `ICErc20Actions.redeem` call
    function _encodeRedeem(uint256 amount) internal pure returns (bytes memory callData) {
        callData = abi.encodeCall(ICErc20Actions.redeem, (amount)); // U:[COMP2-6,7]
    }

    // -------------------- //
    // REDEEMING UNDERLYING //
    // -------------------- //

    /// @notice Burn cTokens to withdraw given amount of underlying from Compound
    /// @param amount Amount of underlying to withdraw
    function redeemUnderlying(uint256 amount)
        external
        override
        creditFacadeOnly // U:[COMP2-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        uint256 error;
        (tokensToEnable, tokensToDisable, error) = _redeemUnderlying(amount); // U:[COMP2-8]
        _revertOnError(error); // U:[COMP2-3]
    }

    /// @dev Internal implementation of `redeemUnderlying`
    ///      Since redeeming process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _redeemUnderlying(uint256 amount)
        internal
        virtual
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error);

    /// @dev Encodes calldata for `ICErc20Actions.redeemUnderlying` call
    function _encodeRedeemUnderlying(uint256 amount) internal pure returns (bytes memory callData) {
        callData = abi.encodeCall(ICErc20Actions.redeemUnderlying, (amount)); // U:[COMP2-8]
    }
}
