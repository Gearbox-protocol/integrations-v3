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
    constructor(address _creditManager, address _targetContract) AbstractAdapter(_creditManager, _targetContract) {}

    /// @dev Reverts if CToken operation produced non-zero error code
    function _revertOnError(uint256 error) internal pure {
        if (error != 0) revert CTokenError(error);
    }

    /// ------- ///
    /// MINTING ///
    /// ------- ///

    /// @inheritdoc ICompoundV2_CTokenAdapter
    function mint(uint256 mintAmount)
        external
        override
        creditFacadeOnly // F: [ACV2CT-1]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        uint256 error;
        (tokensToEnable, tokensToDisable, error) = _mint(mintAmount); // F: [ACV2CT-2, ACV2CT-3]
        _revertOnError(error);
    }

    /// @inheritdoc ICompoundV2_CTokenAdapter
    function mintAll()
        external
        override
        creditFacadeOnly // F: [ACV2CT-1]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        uint256 error;
        (tokensToEnable, tokensToDisable, error) = _mintAll(); // F: [ACV2CT-4, ACV2CT-5]
        _revertOnError(error);
    }

    /// @dev Internal implementation of `mint`
    ///      Since minting process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _mint(uint256 amount)
        internal
        virtual
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error);

    /// @dev Internal implementation of `mintAll`
    ///      Since minting process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _mintAll() internal virtual returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error);

    /// @dev Encodes calldata for `ICErc20Actions.mint` call
    function _encodeMint(uint256 amount) internal pure returns (bytes memory callData) {
        callData = abi.encodeCall(ICErc20Actions.mint, (amount)); // F: [ACV2CT-2, ACV2CT-4]
    }

    /// --------- ///
    /// REDEEMING ///
    /// --------- ///

    /// @inheritdoc ICompoundV2_CTokenAdapter
    function redeem(uint256 amount)
        external
        override
        creditFacadeOnly // F: [ACV2CT-1]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        uint256 error;
        (tokensToEnable, tokensToDisable, error) = _redeem(amount); // F: [ACV2CT-6, ACV2CT-7]
        _revertOnError(error);
    }

    /// @inheritdoc ICompoundV2_CTokenAdapter
    function redeemAll()
        external
        override
        creditFacadeOnly // F: [ACV2CT-1]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        uint256 error;
        (tokensToEnable, tokensToDisable, error) = _redeemAll(); // F: [ACV2CT-8, ACV2CT-9]
        _revertOnError(error);
    }

    /// @dev Internal implementation of `redeem`
    ///      Since redeeming process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _redeem(uint256 amount)
        internal
        virtual
        returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error);

    /// @dev Internal implementation of `redeemAll`
    ///      Since redeeming process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _redeemAll() internal virtual returns (uint256 tokensToEnable, uint256 tokensToDisable, uint256 error);

    /// @dev Encodes calldata for `ICErc20Actions.redeem` call
    function _encodeRedeem(uint256 amount) internal pure returns (bytes memory callData) {
        callData = abi.encodeCall(ICErc20Actions.redeem, (amount)); // F: [ACV2CT-6, ACV2CT-8]
    }

    /// -------------------- ///
    /// REDEEMING UNDERLYING ///
    /// -------------------- ///

    /// @inheritdoc ICompoundV2_CTokenAdapter
    function redeemUnderlying(uint256 amount)
        external
        override
        creditFacadeOnly // F: [ACV2CT-1]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        uint256 error;
        (tokensToEnable, tokensToDisable, error) = _redeemUnderlying(amount); // F: [ACV2CT-10, ACV2CT-11]
        _revertOnError(error);
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
        callData = abi.encodeCall(ICErc20Actions.redeemUnderlying, (amount)); // F: [ACV2CT-10]
    }
}
