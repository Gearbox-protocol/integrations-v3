// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ACLNonReentrantTrait} from "@gearbox-protocol/core-v3/contracts/traits/ACLNonReentrantTrait.sol";
import {ContractsRegisterTrait} from "@gearbox-protocol/core-v3/contracts/traits/ContractsRegisterTrait.sol";

import {IZapper} from "../interfaces/zappers/IZapper.sol";
import {IZapperRegister} from "../interfaces/zappers/IZapperRegister.sol";

contract ZapperRegister is ACLNonReentrantTrait, ContractsRegisterTrait, IZapperRegister {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant override version = 3_00;

    mapping(address => EnumerableSet.AddressSet) internal _zappersMap;

    constructor(address addressProvider)
        ACLNonReentrantTrait(addressProvider)
        ContractsRegisterTrait(addressProvider)
    {}

    function zappers(address pool) external view override returns (address[] memory) {
        return _zappersMap[pool].values();
    }

    function addZapper(address zapper) external override nonZeroAddress(zapper) controllerOnly {
        address pool = IZapper(zapper).pool();
        _ensureRegisteredPool(pool);

        EnumerableSet.AddressSet storage zapperSet = _zappersMap[pool];
        if (!zapperSet.contains(zapper)) {
            zapperSet.add(zapper);
            emit AddZapper(zapper);
        }
    }

    function removeZapper(address zapper) external override nonZeroAddress(zapper) controllerOnly {
        EnumerableSet.AddressSet storage zapperSet = _zappersMap[IZapper(zapper).pool()];
        if (zapperSet.contains(zapper)) {
            zapperSet.remove(zapper);
            emit RemoveZapper(zapper);
        }
    }
}
