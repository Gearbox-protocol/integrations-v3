// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IPhantomTokenWithdrawer} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

/// @title Zircuit pool adapter interface
interface IZircuitPoolAdapter is IAdapter, IPhantomTokenWithdrawer {
    /// @notice Emitted when a supported underlying / phantom token pair is added to adapter
    event AddSupportedUnderlying(address indexed token, address indexed phantomToken);

    /// @notice Thrown when attempting to deposit/withdraw an unsupported underlying
    error UnsupportedUnderlyingException();

    function depositFor(address _token, address, uint256 _amount) external returns (bool useSafePrices);

    function depositDiff(address _token, uint256 _leftoverAmount) external returns (bool useSafePrices);

    function withdraw(address _token, uint256 _amount) external returns (bool useSafePrices);

    function withdrawDiff(address _token, uint256 _leftoverAmount) external returns (bool useSafePrices);

    // --------//
    // GETTERS //
    // --------//

    function tokenToPhantomToken(address token) external view returns (address phantomToken);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function updateSupportedUnderlyings() external;
}
