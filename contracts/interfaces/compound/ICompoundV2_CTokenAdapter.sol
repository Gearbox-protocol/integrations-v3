// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

interface ICompoundV2_Exceptions {
    /// @notice Thrown when cToken operation produces an error
    error CTokenError(uint256 errorCode);
}

/// @title Compound V2 cToken adapter interface
interface ICompoundV2_CTokenAdapter is IAdapter, ICompoundV2_Exceptions {
    function cToken() external view returns (address);

    function underlying() external view returns (address);

    function tokenMask() external view returns (uint256);

    function cTokenMask() external view returns (uint256);

    function mint(uint256 amount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function mintDiff(uint256 leftoverAmount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function mintAll() external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function redeem(uint256 amount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function redeemDiff(uint256 leftoverAmount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function redeemAll() external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function redeemUnderlying(uint256 amount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
