// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {SecuritizeLiquidator} from "../../contracts/integrations/securitize/SecuritizeLiquidator.sol";

contract Upload_2026_09_07_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](1);
        bytecodes[0].contractType = "RWA_LIQUIDATOR::SECURITIZE";
        bytecodes[0].version = 3_12;
        bytecodes[0].initCode = type(SecuritizeLiquidator).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/1f28fcc0c3137a1802dfae9884e6ce0d0a570b07/contracts/integrations/securitize/SecuritizeLiquidator.sol";
    }
}
