// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IZapper as IZapperBase} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IZapper.sol";

interface IZapper is IZapperBase {
    function pool() external view returns (address);

    function underlying() external view returns (address);

    function tokenIn() external view returns (address);

    function tokenOut() external view returns (address);

    function previewDeposit(uint256 tokenInAmount) external view returns (uint256 tokenOutAmount);

    function previewRedeem(uint256 tokenOutAmount) external view returns (uint256 tokenInAmount);

    function redeem(uint256 tokenOutAmount, address receiver) external returns (uint256 tokenInAmount);

    function redeemWithPermit(uint256 tokenOutAmount, address receiver, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 tokenInAmount);

    function redeemWithPermitAllowed(
        uint256 tokenOutAmount,
        address receiver,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 tokenInAmount);
}
