// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;
import { CheatCodes, HEVM_ADDRESS } from "@gearbox-protocol/core-v2/contracts/test/lib/cheatCodes.sol";

interface ISupportedContracts {
    function addressOf(Contracts c) external view returns (address);

    function nameOf(Contracts c) external view returns (string memory);

    function contractIndex(address) external view returns (Contracts);

    function contractCount() external view returns (uint256);
}

enum Contracts {
    NO_CONTRACT
    // $CONTRACTS_ENUM$
}

struct ContractData {
    Contracts id;
    address addr;
    string name;
}

contract SupportedContracts is ISupportedContracts {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    mapping(Contracts => address) public override addressOf;
    mapping(Contracts => string) public override nameOf;
    mapping(address => Contracts) public override contractIndex;

    uint256 public override contractCount;

    constructor(uint8 networkId) {

        if (networkId != 1) {
            revert("Network id not supported");
        }

        ContractData[] memory cd;
        // $CONTRACTS_ADDRESSES$

        uint256 len = cd.length;
        contractCount = len;
        unchecked {
            for (uint256 i; i < len; ++i) {
                addressOf[cd[i].id] = cd[i].addr;
                nameOf[cd[i].id] = cd[i].name;
                contractIndex[cd[i].addr] = cd[i].id;

                evm.label(cd[i].addr, cd[i].name);
            }
        }
    }
}
