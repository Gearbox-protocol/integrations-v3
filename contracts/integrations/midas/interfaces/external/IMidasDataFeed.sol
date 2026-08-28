// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IMidasDataFeed {
    /// @notice Current mToken rate in 1e18 base units
    /// @dev Used by redeemers configured for current-rate pricing
    function getDataInBase18() external view returns (uint256);
}
