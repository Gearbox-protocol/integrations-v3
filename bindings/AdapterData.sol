// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Tokens } from "./Tokens.sol";
import { Contracts } from "./SupportedContracts.sol";
import { AdapterType } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

struct SimpleAdapter {
    Contracts targetContract;
    AdapterType adapterType;
}

struct CurveAdapter {
    Contracts targetContract;
    AdapterType adapterType;
    Tokens lpToken;
    Contracts basePool;
}

struct CurveStETHAdapter {
    Contracts curveETHGateway;
    AdapterType adapterType;
    Tokens lpToken;
}

struct CurveWrapper {
    Contracts targetContract;
    AdapterType adapterType;
    Tokens lpToken;
    uint256 nCoins;
}

struct ConvexBasePoolAdapter {
    Contracts targetContract;
    AdapterType adapterType;
    Tokens stakedToken;
}

contract AdapterData {
    SimpleAdapter[] simpleAdapters;
    CurveAdapter[] curveAdapters;
    CurveStETHAdapter curveStEthAdapter;
    CurveWrapper[] curveWrappers;
    ConvexBasePoolAdapter[] convexBasePoolAdapters;

    constructor() {
        // $ADAPTERS_LIST
    }
}
