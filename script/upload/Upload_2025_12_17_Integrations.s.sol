// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {UpshiftVaultGateway} from "../../contracts/helpers/upshift/UpshiftVaultGateway.sol";

contract Upload_2025_12_17_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](1);
        bytecodes[0].contractType = "GATEWAY::UPSHIFT_VAULT";
        bytecodes[0].version = 3_11;
        bytecodes[0].initCode = type(UpshiftVaultGateway).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/bdc69ec0de108b66f32109c6bab19a89cf7062b1/contracts/helpers/upshift/UpshiftVaultGateway.sol";
    }
}
