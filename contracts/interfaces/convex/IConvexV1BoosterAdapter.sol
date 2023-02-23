// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { IAdapter } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

interface IConvexV1BoosterAdapter is IAdapter {
    /// @dev CRV token
    function crv() external view returns (address);

    /// @dev CVX token
    function minter() external view returns (address);

    /// @dev Maps pid to a pseudo-ERC20 token that represents the staked position
    function pidToPhantomToken(uint256) external view returns (address);

    function deposit(uint256 _pid, uint256, bool _stake) external;

    function depositAll(uint256 _pid, bool _stake) external;

    function withdraw(uint256 _pid, uint256) external;

    function withdrawAll(uint256 _pid) external;

    /// @dev Scans the Credit Manager's allowed contracts for Convex pool
    ///      adapters and adds the corresponding phantom tokens to an internal mapping
    /// @notice Admin function. The mapping is used to determine an output token from the
    ///         pool's pid, when deposit is called with stake == true
    function updateStakedPhantomTokensMap() external;
}
