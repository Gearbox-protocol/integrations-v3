// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ZircuitPoolAdapter} from "../../../../adapters/zircuit/ZircuitPoolAdapter.sol";

contract ZircuitPoolAdapterHarness is ZircuitPoolAdapter {
    constructor(address _creditManager, address _pool) ZircuitPoolAdapter(_creditManager, _pool) {}

    function hackTokenToPhantomToken(address token, address phantomToken) external {
        tokenToPhantomToken[token] = phantomToken;
    }
}
