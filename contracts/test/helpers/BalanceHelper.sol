// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";

import {BalanceEngine} from "@gearbox-protocol/core-v3/contracts/test/helpers/BalanceEngine.sol";

/// @title CreditManagerV3TestSuite
/// @notice Deploys contract for unit testing of CreditManagerV3.sol
contract BalanceHelper is BalanceEngine {
// Suites

// modifier withTokenSuite() {
//     require(address(tokenTestSuite) != address(0), "tokenTestSuite is not set");
//     _;
// }

// function expectBalance(Tokens t, address holder, uint256 expectedBalance) internal withTokenSuite {
//     expectBalance(t, holder, expectedBalance, "");
// }

// function expectBalance(Tokens t, address holder, uint256 expectedBalance, string memory reason)
//     internal
//     withTokenSuite
// {
//     expectBalance(tokenTestSuite.addressOf(t), holder, expectedBalance, reason);
// }

// function expectBalanceGe(Tokens t, address holder, uint256 minBalance, string memory reason)
//     internal
//     withTokenSuite
// {
//     require(address(tokenTestSuite) != address(0), "tokenTestSuite is not set");

//     expectBalanceGe(tokenTestSuite.addressOf(t), holder, minBalance, reason);
// }

// function expectBalanceLe(Tokens t, address holder, uint256 maxBalance, string memory reason)
//     internal
//     withTokenSuite
// {
//     expectBalanceLe(tokenTestSuite.addressOf(t), holder, maxBalance, reason);
// }

// function expectAllowance(Tokens t, address owner, address spender, uint256 expectedAllowance)
//     internal
//     withTokenSuite
// {
//     expectAllowance(t, owner, spender, expectedAllowance, "");
// }

// function expectAllowance(Tokens t, address owner, address spender, uint256 expectedAllowance, string memory reason)
//     internal
//     withTokenSuite
// {
//     require(address(tokenTestSuite) != address(0), "tokenTestSuite is not set");

//     expectAllowance(tokenTestSuite.addressOf(t), owner, spender, expectedAllowance, reason);
// }
}
