// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {Mellow4626VaultAdapter} from "../../contracts/integrations/mellow/Mellow4626VaultAdapter.sol";
import {MellowClaimerAdapter} from "../../contracts/integrations/mellow/MellowClaimerAdapter.sol";
import {MellowWithdrawalPhantomToken} from "../../contracts/integrations/mellow/MellowWithdrawalPhantomToken.sol";

contract Upload_2025_08_02_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](3);
        bytecodes[0].contractType = "ADAPTER::MELLOW_ERC4626_VAULT";
        bytecodes[0].version = 3_12;
        bytecodes[0].initCode = type(Mellow4626VaultAdapter).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/0d992f9d01f4f936b13ba242e7b6ffaf2a88a976/contracts/adapters/mellow/Mellow4626VaultAdapter.sol";

        bytecodes[1].contractType = "ADAPTER::MELLOW_CLAIMER";
        bytecodes[1].version = 3_10;
        bytecodes[1].initCode = type(MellowClaimerAdapter).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/0d992f9d01f4f936b13ba242e7b6ffaf2a88a976/contracts/adapters/mellow/MellowClaimerAdapter.sol";

        bytecodes[2].contractType = "PHANTOM_TOKEN::MELLOW_WITHDRAWAL";
        bytecodes[2].version = 3_12;
        bytecodes[2].initCode = type(MellowWithdrawalPhantomToken).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/0d992f9d01f4f936b13ba242e7b6ffaf2a88a976/contracts/helpers/mellow/MellowWithdrawalPhantomToken.sol";
    }
}
