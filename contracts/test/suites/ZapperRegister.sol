// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {ACLTrait} from "@gearbox-protocol/core-v3/contracts/traits/ACLTrait.sol";
import {ContractsRegisterTrait} from "@gearbox-protocol/core-v3/contracts/traits/ContractsRegisterTrait.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

import {IZapper} from "../../interfaces/zappers/IZapper.sol";

contract ZapperRegister is IVersion, ACLTrait, ContractsRegisterTrait, SanityCheckTrait {
    using EnumerableSet for EnumerableSet.AddressSet;

    event AddZapper(address indexed zapper);
    event RemoveZapper(address indexed zapper);

    uint256 public constant version = 3_10;
    bytes32 public constant contractType = "ZR";

    mapping(address => EnumerableSet.AddressSet) internal _zappersMap;

    constructor(address acl_, address contractsRegister_) ACLTrait(acl_) ContractsRegisterTrait(contractsRegister_) {}

    function zappers(address pool) external view returns (address[] memory) {
        return _zappersMap[pool].values();
    }

    function addZapper(address zapper) external nonZeroAddress(zapper) configuratorOnly {
        address pool = IZapper(zapper).pool();
        _ensureRegisteredPool(pool);

        EnumerableSet.AddressSet storage zapperSet = _zappersMap[pool];
        if (!zapperSet.contains(zapper)) {
            zapperSet.add(zapper);
            emit AddZapper(zapper);
        }
    }

    function removeZapper(address zapper) external nonZeroAddress(zapper) configuratorOnly {
        EnumerableSet.AddressSet storage zapperSet = _zappersMap[IZapper(zapper).pool()];
        if (zapperSet.contains(zapper)) {
            zapperSet.remove(zapper);
            emit RemoveZapper(zapper);
        }
    }
}
