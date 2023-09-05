// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Tokens } from "./Tokens.sol";
import { TokenData } from "../suites/TokensTestSuite.sol";
import { TokenType } from "../../integrations/TokenType.sol";

contract TokensDataLive {
    TokenData[] tokenData;

    constructor(uint8 networkId) {

        if (networkId != 1) {
            revert("Network id not supported");
        }

        TokenData[] memory td;

        // $TOKEN_ADDRESSES$

        for (uint256 i = 0; i < td.length; ++i) {
            tokenData.push(td[i]);
        }
    }

    function getTokenData() external view returns (TokenData[] memory) {
        return tokenData;
    }
}
