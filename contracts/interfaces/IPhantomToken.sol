// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

interface IPhantomToken {
    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view returns (address targetContract, address underlying);
}

interface IPhantomTokenWithdrawer {
    /// @notice Withdraws phantom token for its underlying
    function withdrawPhantomToken(address token, uint256 amount) external returns (bool useSafePrices);
}
