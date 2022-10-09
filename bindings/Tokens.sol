// SPDX-License-Identifier: BUSL-1.1
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox.fi, 2021
pragma solidity ^0.8.10;
import "@gearbox-protocol/core-v2/contracts/test/lib/test.sol";
import { CheatCodes, HEVM_ADDRESS } from "@gearbox-protocol/core-v2/contracts/test/lib/cheatCodes.sol";
import { TokenType } from "../../integrations/TokenType.sol";

/// @dev c-Tokens and LUNA are added for unit test purposes
enum Tokens {
    NO_TOKEN,
    cDAI,
    cUSDC,
    cUSDT,
    cLINK,
    LUNA
    // $TOKENS$
}
