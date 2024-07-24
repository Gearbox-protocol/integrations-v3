// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ZircuitPoolAdapter} from "../../../../adapters/zircuit/ZircuitPoolAdapter.sol";

contract ZircuitPoolAdapterHarness is ZircuitPoolAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(address _creditManager, address _pool) ZircuitPoolAdapter(_creditManager, _pool) {}

    function hackTokenToPhantomToken(address token, address phantomToken) external {
        tokenToPhantomToken[token] = phantomToken;
    }

    function hackSupportedUnderlyings(address token) external {
        _supportedUnderlyings.add(token);
    }
}
