// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

interface IERC4626Adapter {
    function deposit(uint256 assets, address) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function depositAll() external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function mint(uint256 shares, address) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function withdraw(uint256 assets, address, address)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function redeem(uint256 shares, address, address)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function redeemAll() external returns (uint256 tokensToEnable, uint256 tokensToDisable);
}
