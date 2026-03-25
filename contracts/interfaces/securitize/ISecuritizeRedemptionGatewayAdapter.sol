// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IPhantomTokenAdapter} from "../IPhantomTokenAdapter.sol";
import {ISecuritizeWhitelister, Signature} from "../../integrations/securitize/ISecuritizeWhitelister.sol";

/// @title Securitize Redemption Gateway adapter interface
interface ISecuritizeRedemptionGatewayAdapter is IPhantomTokenAdapter {
    error InvalidRedemptionGatewayException();

    function dsToken() external view returns (address);

    function stableCoinToken() external view returns (address);

    function redemptionPhantomToken() external view returns (address);

    function redeem(uint256 dsTokenAmount, Signature calldata userSignature) external returns (bool);

    function redeemDiff(uint256 leftoverAmount, Signature calldata userSignature) external returns (bool);

    function claim(address[] calldata redeemers) external returns (bool);

    function transferRedeemer(address redeemer, address newAccount) external returns (bool);
}
