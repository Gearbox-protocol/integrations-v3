// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

interface IZapper {
    function pool() external view returns (address);

    function tokenOut() external view returns (address);

    function unwrappedToken() external view returns (address);

    function wrappedToken() external view returns (address);

    function previewDeposit(uint256 amount) external view returns (uint256 shares);

    function previewRedeem(uint256 shares) external view returns (uint256 amount);

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 amount);

    function redeemWithPermit(
        uint256 shares,
        address receiver,
        address owner,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amount);
}
