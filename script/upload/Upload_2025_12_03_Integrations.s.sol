// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {UpshiftVaultAdapter} from "../../contracts/adapters/upshift/UpshiftVaultAdapter.sol";

contract Upload_2025_12_03_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](1);
        bytecodes[0].contractType = "ADAPTER::UPSHIFT_VAULT";
        bytecodes[0].version = 3_11;
        bytecodes[0].initCode = type(UpshiftVaultAdapter).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/7a286681d96c61999e24d37067ca25bd92332c89/contracts/adapters/upshift/UpshiftVaultAdapter.sol";
    }
}
