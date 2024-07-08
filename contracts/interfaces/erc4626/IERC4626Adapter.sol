// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAdapter} from "../../interfaces/IAdapter.sol";

interface IERC4626Adapter is IAdapter {
    function asset() external view returns (address);

    function assetMask() external view returns (uint256);

    function sharesMask() external view returns (uint256);

    function deposit(uint256 assets, address) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function depositDiff(uint256 leftoverAmount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function mint(uint256 shares, address) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdraw(uint256 assets, address, address)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function redeem(uint256 shares, address, address)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function redeemDiff(uint256 leftoverAmount) external returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
