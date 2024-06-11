// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

interface IZircuitPoolAdapterEvents {
    /// @notice Emitted when phantom staked token is set for the pool
    event SetTokenToPhantomToken(address indexed token, address indexed phantomToken);
}

/// @title Zircuit pool adapter interface
interface IZircuitPoolAdapter is IAdapter, IZircuitPoolAdapterEvents {
    function depositFor(address _token, address, uint256 _amount)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function depositDiff(address _token, uint256 _leftoverAmount)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdraw(address _token, uint256 _amount)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdrawDiff(address _token, uint256 _leftoverAmount)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function updatePhantomTokensMap() external;
}
