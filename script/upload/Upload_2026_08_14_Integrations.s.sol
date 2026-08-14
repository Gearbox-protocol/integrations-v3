// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {MidasGateway} from "../../contracts/integrations/midas/MidasGateway.sol";
import {MidasGatewayAdapter} from "../../contracts/integrations/midas/MidasGatewayAdapter.sol";
import {MidasIssuanceVaultAdapter} from "../../contracts/integrations/midas/MidasIssuanceVaultAdapter.sol";
import {MidasRedemptionVaultAdapter} from "../../contracts/integrations/midas/MidasRedemptionVaultAdapter.sol";
import {MidasLiquidator} from "../../contracts/integrations/midas/MidasLiquidator.sol";
import {
    MidasRedemptionVaultPhantomToken
} from "../../contracts/integrations/midas/MidasRedemptionVaultPhantomToken.sol";
import {MidasDegenNFT} from "../../contracts/integrations/midas/MidasDegenNFT.sol";
import {MidasAliasedLossPolicyV3} from "../../contracts/integrations/midas/MidasAliasedLossPolicyV3.sol";

contract Upload_2026_08_14_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](8);
        bytecodes[0].contractType = "GATEWAY::MIDAS";
        bytecodes[0].version = 3_11;
        bytecodes[0].initCode = type(MidasGateway).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/22754fff8278c5338e5ff0249d9c37d4680186f4/contracts/integrations/midas/MidasGateway.sol";

        bytecodes[1].contractType = "ADAPTER::MIDAS_GATEWAY";
        bytecodes[1].version = 3_11;
        bytecodes[1].initCode = type(MidasGatewayAdapter).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/22754fff8278c5338e5ff0249d9c37d4680186f4/contracts/integrations/midas/MidasGatewayAdapter.sol";

        bytecodes[2].contractType = "ADAPTER::MIDAS_ISSUANCE_VAULT";
        bytecodes[2].version = 3_11;
        bytecodes[2].initCode = type(MidasIssuanceVaultAdapter).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/22754fff8278c5338e5ff0249d9c37d4680186f4/contracts/integrations/midas/MidasIssuanceVaultAdapter.sol";

        bytecodes[3].contractType = "ADAPTER::MIDAS_REDEMPTION_VAULT";
        bytecodes[3].version = 3_11;
        bytecodes[3].initCode = type(MidasRedemptionVaultAdapter).creationCode;
        bytecodes[3].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/22754fff8278c5338e5ff0249d9c37d4680186f4/contracts/integrations/midas/MidasRedemptionVaultAdapter.sol";

        bytecodes[4].contractType = "RWA_LIQUIDATOR::MIDAS";
        bytecodes[4].version = 3_11;
        bytecodes[4].initCode = type(MidasLiquidator).creationCode;
        bytecodes[4].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/22754fff8278c5338e5ff0249d9c37d4680186f4/contracts/integrations/midas/MidasLiquidator.sol";

        bytecodes[5].contractType = "PHANTOM_TOKEN::MIDAS_REDEMPTION";
        bytecodes[5].version = 3_11;
        bytecodes[5].initCode = type(MidasRedemptionVaultPhantomToken).creationCode;
        bytecodes[5].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/22754fff8278c5338e5ff0249d9c37d4680186f4/contracts/integrations/midas/MidasRedemptionVaultPhantomToken.sol";

        bytecodes[6].contractType = "DEGEN_NFT::MIDAS";
        bytecodes[6].version = 3_11;
        bytecodes[6].initCode = type(MidasDegenNFT).creationCode;
        bytecodes[6].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/22754fff8278c5338e5ff0249d9c37d4680186f4/contracts/integrations/midas/MidasDegenNFT.sol";

        bytecodes[7].contractType = "LOSS_POLICY::MIDAS_ALIASED";
        bytecodes[7].version = 3_11;
        bytecodes[7].initCode = type(MidasAliasedLossPolicyV3).creationCode;
        bytecodes[7].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/22754fff8278c5338e5ff0249d9c37d4680186f4/contracts/integrations/midas/MidasAliasedLossPolicyV3.sol";
    }
}
