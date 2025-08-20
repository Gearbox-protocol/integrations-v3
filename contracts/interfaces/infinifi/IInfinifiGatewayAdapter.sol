// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

struct LockedTokenStatus {
    address lockedToken;
    uint32 unwindingEpochs;
    bool allowed;
}

interface IInfinifiGatewayEvents {
    event SetLockedTokenStatus(address lockedToken, uint32 unwindingEpochs, bool allowed);
}

interface IInfinifiGatewayExceptions {
    /// @notice Thrown when the passed unwinding epochs for the locked token do not match actual unwinding epochs in Infinifi
    error LockedTokenUnwindingEpochsMismatchException();

    /// @notice Thrown when the locked token is not allowed
    error LockedTokenNotAllowedException();
}

/// @title Infinifi Gateway adapter interface
interface IInfinifiGatewayAdapter is IAdapter, IInfinifiGatewayExceptions, IInfinifiGatewayEvents {
    function usdc() external view returns (address);

    function iusd() external view returns (address);

    function siusd() external view returns (address);

    function mint(address to, uint256 amount) external returns (bool useSafePrices);

    function mintDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    function stake(address to, uint256 amount) external returns (bool useSafePrices);

    function stakeDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    function unstake(address to, uint256 amount) external returns (bool useSafePrices);

    function unstakeDiff(uint256 leftoverAmount) external returns (bool useSafePrices);

    function createPosition(uint256 amount, uint32 unwindingEpochs) external returns (bool useSafePrices);

    function createPositionDiff(uint256 leftoverAmount, uint32 unwindingEpochs) external returns (bool useSafePrices);

    function redeem(address to, uint256 amount, uint256 minAssetsOut) external returns (bool useSafePrices);

    function redeemDiff(uint256 leftoverAmount, uint256 minRateRAY) external returns (bool useSafePrices);

    function claimRedemption() external returns (bool useSafePrices);

    function getAllowedLockedTokens() external view returns (address[] memory);

    function setLockedTokenBatchStatus(LockedTokenStatus[] calldata lockedTokens) external;
}
