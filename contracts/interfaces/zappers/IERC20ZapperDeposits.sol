// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

interface IERC20ZapperDeposits {
    function deposit(uint256 tokenInAmount, address receiver) external returns (uint256 tokenOutAmount);

    function depositWithPermit(uint256 tokenInAmount, address receiver, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 tokenOutAmount);

    function depositWithReferral(uint256 tokenInAmount, address receiver, uint256 referralCode)
        external
        returns (uint256 tokenOutAmount);

    function depositWithReferralAndPermit(
        uint256 tokenInAmount,
        address receiver,
        uint256 referralCode,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 tokenOutAmount);
}
