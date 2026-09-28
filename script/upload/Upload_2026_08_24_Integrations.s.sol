// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {RedemptionLogger} from "../../contracts/integrations/common/RedemptionLogger.sol";

contract Upload_2026_08_24_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](1);
        bytecodes[0].contractType = "LOGGER::REDEMPTION_LOGGER";
        bytecodes[0].version = 3_10;
        bytecodes[0].initCode = type(RedemptionLogger).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/38ee0623547f9d0df65bddea62e26751c9bae1a7/contracts/integrations/common/RedemptionLogger.sol";
    }
}
