// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "../IAdapter.sol";

interface IZircuitPoolAdapterEvents {
    /// @notice Emitted when a supported underlying / phantom token pair is added to adapter
    event AddSupportedUnderlying(address indexed token, address indexed phantomToken);
}

interface IZircuitPoolAdapterExceptions {
    /// @notice Thrown when attempting to deposit/withdraw an unsupported underlying
    error UnsupportedUnderlyingException();
}

/// @title Zircuit pool adapter interface
interface IZircuitPoolAdapter is IAdapter, IZircuitPoolAdapterEvents, IZircuitPoolAdapterExceptions {
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