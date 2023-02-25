// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { AbstractAdapter } from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";

import { ICErc20Actions } from "../../integrations/compound/ICErc20.sol";
import { ICompoundV2_CTokenAdapter, CTokenError } from "../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";

/// @title Compound V2 cToken adapter
/// @notice Implements logic for CAs to interact with Compound's cTokens
/// @dev Abstract base contract for CErc20 and CEther adapters
abstract contract CompoundV2_CTokenAdapter is
    AbstractAdapter,
    ICompoundV2_CTokenAdapter
{
    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _targetContract Target contract address, must implement `ICErc20Actions`
    constructor(
        address _creditManager,
        address _targetContract
    ) AbstractAdapter(_creditManager, _targetContract) {}

    /// @dev Reverts if CToken operation produced non-zero error code
    function _revertOnError(uint256 error) internal pure {
        if (error != 0) revert CTokenError(error);
    }

    /// ------- ///
    /// MINTING ///
    /// ------- ///

    /// @notice Deposit given amount of underlying tokens into Compound in exchange for cTokens
    /// @param mintAmount Amount of underlying tokens to deposit
    function mint(uint256 mintAmount) external override creditFacadeOnly {
        _revertOnError(_mint(mintAmount));
    }

    /// @notice Deposit all underlying tokens into Compound in exchange for cTokens, disables underlying
    function mintAll() external override creditFacadeOnly {
        _revertOnError(_mintAll());
    }

    /// @dev Internal implementation of `mint`
    ///      Since minting process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _mint(uint256 amount) internal virtual returns (uint256 error);

    /// @dev Internal implementation of `mintAll`
    ///      Since minting process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _mintAll() internal virtual returns (uint256 error);

    /// @dev Encodes calldata for `ICErc20Actions.mint` call
    function _encodeMint(
        uint256 amount
    ) internal pure returns (bytes memory callData) {
        callData = abi.encodeCall(ICErc20Actions.mint, (amount));
    }

    /// --------- ///
    /// REDEEMING ///
    /// --------- ///

    /// @notice Burn given amount of cTokens to withdraw underlying from Compound
    /// @param amount Amount of cTokens to burn
    function redeem(uint256 amount) external override creditFacadeOnly {
        _revertOnError(_redeem(amount));
    }

    /// @notice Burn all balance of CTokens to Compound to withdraw all underlying, disables CToken
    function redeemAll() external override creditFacadeOnly {
        _revertOnError(_redeemAll());
    }

    /// @dev Internal implementation of `redeem`
    ///      Since redeeming process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _redeem(uint256 amount) internal virtual returns (uint256 error);

    /// @dev Internal implementation of `redeemAll`
    ///      Since redeeming process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _redeemAll() internal virtual returns (uint256 error);

    /// @dev Encodes calldata for `ICErc20Actions.redeem` call
    function _encodeRedeem(
        uint256 amount
    ) internal pure returns (bytes memory callData) {
        callData = abi.encodeCall(ICErc20Actions.redeem, (amount));
    }

    /// -------------------- ///
    /// REDEEMING UNDERLYING ///
    /// -------------------- ///

    /// @notice Burn cTokens to withdraw given amount of underlying from Compound
    /// @param amount Amount of underlying to withdraw
    function redeemUnderlying(
        uint256 amount
    ) external override creditFacadeOnly {
        _revertOnError(_redeemUnderlying(amount));
    }

    /// @dev Internal implementation of `redeemUnderlying`
    ///      Since redeeming process might be different for CErc20 and CEther,
    ///      it's up to deriving adapters to implement this function
    function _redeemUnderlying(
        uint256 amount
    ) internal virtual returns (uint256 error);

    /// @dev Encodes calldata for `ICErc20Actions.redeemUnderlying` call
    function _encodeRedeemUnderlying(
        uint256 amount
    ) internal pure returns (bytes memory callData) {
        callData = abi.encodeCall(ICErc20Actions.redeemUnderlying, (amount));
    }
}
