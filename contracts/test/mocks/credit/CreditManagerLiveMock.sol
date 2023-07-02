// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {CreditManagerV3} from "@gearbox-protocol/core-v3/contracts/credit/CreditManagerV3.sol";

contract CreditManagerLiveMock is CreditManagerV3 {
    constructor(address _pool) CreditManagerV3(_pool) {}

    function _fullCollateralCheck(address creditAccount, uint256[] memory collateralHints, uint16 minHealthFactor)
        internal
        override
    {}

    function _checkAndEnableToken(address creditAccount, address token) internal override {}

    function _disableToken(address creditAccount, address token) internal override returns (bool) {}

    function _changeEnabledTokens(address creditAccount, uint256 tokensToEnable, uint256 tokensToDisable)
        internal
        override
        returns (bool, bool)
    {}
}
