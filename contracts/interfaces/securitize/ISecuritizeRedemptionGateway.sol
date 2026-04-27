// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";

interface ISecuritizeRedemptionGateway is IVersion {
    error RedeemerNotOwnedByAccountException();
    error RedeemerTransferNotAllowedException();
    error MaxUnclaimedRedeemersPerAccountException();

    function dsToken() external view returns (address);
    function stableCoinToken() external view returns (address);
    function redemptionAccount() external view returns (address);
    function securitizeWhitelister() external view returns (address);
    function masterRedeemer() external view returns (address);
    function transferMaster() external view returns (address);
    function navProvider() external view returns (address);
    function redeem(uint256 dsTokenAmount) external;
    function claim(address[] calldata redeemers) external;
    function transferRedeemer(address redeemer, address newAccount) external;
    function getRedemptionAmount(address account) external view returns (uint256);
    function getRedeemers(address account) external view returns (address[] memory);
    function getUnclaimedRedeemers(address account) external view returns (address[] memory);
}
