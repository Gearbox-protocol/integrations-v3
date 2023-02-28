// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {CreditManager} from "@gearbox-protocol/core-v2/contracts/credit/CreditManager.sol";

contract CreditManagerLiveMock is CreditManager {
    constructor(address _pool) CreditManager(_pool) {}

    function _fullCollateralCheck(address creditAccount, uint256[] memory collateralHints, uint16 minHealthFactor)
        internal
        override
    {}

    function _checkAndEnableToken(address creditAccount, address token) internal override {}
}
