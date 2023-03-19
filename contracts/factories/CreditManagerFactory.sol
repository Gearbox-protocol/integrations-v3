// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {CreditManagerOpts} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditConfigurator.sol";
import {CreditManagerFactoryBase} from "@gearbox-protocol/core-v2/contracts/factories/CreditManagerFactoryBase.sol";

contract CreditManagerFactory is CreditManagerFactoryBase {
    constructor(address _pool, CreditManagerOpts memory opts, uint256 salt)
        CreditManagerFactoryBase(_pool, opts, salt)
    {}
}
