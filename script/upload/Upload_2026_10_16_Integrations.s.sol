// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {TreehouseRedemptionGateway} from "../../contracts/integrations/treehouse/TreehouseRedemptionGateway.sol";
import {
    TreehouseRedemptionGatewayAdapter
} from "../../contracts/integrations/treehouse/TreehouseRedemptionGatewayAdapter.sol";
import {TreehouseFastlaneAdapter} from "../../contracts/integrations/treehouse/TreehouseFastlaneAdapter.sol";
import {TreehouseRouterAdapter} from "../../contracts/integrations/treehouse/TreehouseRouterAdapter.sol";
import {TreehouseLiquidator} from "../../contracts/integrations/treehouse/TreehouseLiquidator.sol";
import {
    TreehouseRedemptionPhantomToken
} from "../../contracts/integrations/treehouse/TreehouseRedemptionPhantomToken.sol";

contract Upload_2026_10_16_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](6);
        bytecodes[0].contractType = "GATEWAY::TREEHOUSE_REDEMPTION";
        bytecodes[0].version = 3_10;
        bytecodes[0].initCode = type(TreehouseRedemptionGateway).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/a8ca0441b01191879c4ca06518eb27fcb274e9ad/contracts/integrations/treehouse/TreehouseRedemptionGateway.sol";

        bytecodes[1].contractType = "ADAPTER::TREEHOUSE_GATEWAY";
        bytecodes[1].version = 3_10;
        bytecodes[1].initCode = type(TreehouseRedemptionGatewayAdapter).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/a8ca0441b01191879c4ca06518eb27fcb274e9ad/contracts/integrations/treehouse/TreehouseRedemptionGatewayAdapter.sol";

        bytecodes[2].contractType = "ADAPTER::TREEHOUSE_FASTLANE";
        bytecodes[2].version = 3_10;
        bytecodes[2].initCode = type(TreehouseFastlaneAdapter).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/a8ca0441b01191879c4ca06518eb27fcb274e9ad/contracts/integrations/treehouse/TreehouseFastlaneAdapter.sol";

        bytecodes[3].contractType = "ADAPTER::TREEHOUSE_ROUTER";
        bytecodes[3].version = 3_10;
        bytecodes[3].initCode = type(TreehouseRouterAdapter).creationCode;
        bytecodes[3].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/a8ca0441b01191879c4ca06518eb27fcb274e9ad/contracts/integrations/treehouse/TreehouseRouterAdapter.sol";

        bytecodes[4].contractType = "RWA_LIQUIDATOR::TREEHOUSE";
        bytecodes[4].version = 3_10;
        bytecodes[4].initCode = type(TreehouseLiquidator).creationCode;
        bytecodes[4].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/a8ca0441b01191879c4ca06518eb27fcb274e9ad/contracts/integrations/treehouse/TreehouseLiquidator.sol";

        bytecodes[5].contractType = "PHANTOM_TOKEN::TREEHOUSE_RD";
        bytecodes[5].version = 3_10;
        bytecodes[5].initCode = type(TreehouseRedemptionPhantomToken).creationCode;
        bytecodes[5].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/a8ca0441b01191879c4ca06518eb27fcb274e9ad/contracts/integrations/treehouse/TreehouseRedemptionPhantomToken.sol";
    }
}
