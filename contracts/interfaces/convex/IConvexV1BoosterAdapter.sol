// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "../IAdapter.sol";

interface IConvexV1BoosterAdapterEvents {
    /// @notice Emitted when phantom staked token is set for the pool
    event SetPidToPhantomToken(uint256 indexed pid, address indexed phantomToken);
}

/// @title Convex V1 Booster adapter interface
interface IConvexV1BoosterAdapter is IAdapter, IConvexV1BoosterAdapterEvents {
    function deposit(uint256 _pid, uint256, bool _stake)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function depositDiff(uint256 leftoverAmount, uint256 _pid, bool _stake)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdraw(uint256 _pid, uint256) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdrawDiff(uint256 leftoverAmount, uint256 _pid)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    function pidToPhantomToken(uint256) external view returns (address);

    function updateStakedPhantomTokensMap() external;
}
