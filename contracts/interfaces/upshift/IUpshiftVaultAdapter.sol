// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IERC4626Adapter} from "../erc4626/IERC4626Adapter.sol";
import {IPhantomTokenAdapter} from "../IPhantomTokenAdapter.sol";

interface IUpshiftVaultAdapter is IERC4626Adapter, IPhantomTokenAdapter {
    /// @notice Address of the staked phantom token
    function stakedPhantomToken() external view returns (address);

    /// @notice Requests a redemption from the Upshift vault through the gateway
    function requestRedeem(uint256 shares) external returns (bool);

    /// @notice Requests a redemption from the Upshift vault through the gateway, with a specified leftover amount
    function requestRedeemDiff(uint256 leftoverAmount) external returns (bool);

    /// @notice Claims a redemption from the Upshift vault through the gateway
    function claim(uint256 amount) external returns (bool);
}
