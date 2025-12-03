// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {MidasIssuanceVaultAdapter} from "../../contracts/adapters/midas/MidasIssuanceVaultAdapter.sol";
import {MidasRedemptionVaultAdapter} from "../../contracts/adapters/midas/MidasRedemptionVaultAdapter.sol";
import {MidasRedemptionVaultGateway} from "../../contracts/helpers/midas/MidasRedemptionVaultGateway.sol";
import {MidasRedemptionVaultPhantomToken} from "../../contracts/helpers/midas/MidasRedemptionVaultPhantomToken.sol";

contract Upload_2025_10_31_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](4);
        bytecodes[0].contractType = "ADAPTER::MIDAS_ISSUANCE_VAULT";
        bytecodes[0].version = 3_10;
        bytecodes[0].initCode = type(MidasIssuanceVaultAdapter).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/cd8f68dd72ccb27eb0251c14759f6c8dc75358fc/contracts/adapters/midas/MidasIssuanceVaultAdapter.sol";

        bytecodes[1].contractType = "ADAPTER::MIDAS_REDEMPTION_VAULT";
        bytecodes[1].version = 3_10;
        bytecodes[1].initCode = type(MidasRedemptionVaultAdapter).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/cd8f68dd72ccb27eb0251c14759f6c8dc75358fc/contracts/adapters/midas/MidasRedemptionVaultAdapter.sol";

        bytecodes[2].contractType = "GATEWAY::MIDAS_REDEMPTION_VAULT";
        bytecodes[2].version = 3_10;
        bytecodes[2].initCode = type(MidasRedemptionVaultGateway).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/cd8f68dd72ccb27eb0251c14759f6c8dc75358fc/contracts/helpers/midas/MidasRedemptionVaultGateway.sol";

        bytecodes[3].contractType = "PHANTOM_TOKEN::MIDAS_REDEMPTION";
        bytecodes[3].version = 3_10;
        bytecodes[3].initCode = type(MidasRedemptionVaultPhantomToken).creationCode;
        bytecodes[3].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/cd8f68dd72ccb27eb0251c14759f6c8dc75358fc/contracts/helpers/midas/MidasRedemptionVaultPhantomToken.sol";
    }
}
