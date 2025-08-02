// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {KodiakIslandGatewayAdapter} from "../../contracts/adapters/kodiak/KodiakIslandGatewayAdapter.sol";
import {Mellow4626VaultAdapter} from "../../contracts/adapters/mellow/Mellow4626VaultAdapter.sol";
import {MellowClaimerAdapter} from "../../contracts/adapters/mellow/MellowClaimerAdapter.sol";
import {KodiakIslandGateway} from "../../contracts/helpers/kodiak/KodiakIslandGateway.sol";
import {MellowWithdrawalPhantomToken} from "../../contracts/helpers/mellow/MellowWithdrawalPhantomToken.sol";

import {KodiakIslandPriceFeed} from "@gearbox-protocol/oracles-v3/contracts/oracles/kodiak/KodiakIslandPriceFeed.sol";

contract Upload_2025_08_02_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](6);
        bytecodes[0].contractType = "ADAPTER::KODIAK_ISLAND_GATEWAY";
        bytecodes[0].version = 3_10;
        bytecodes[0].initCode = type(KodiakIslandGatewayAdapter).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/0d992f9d01f4f936b13ba242e7b6ffaf2a88a976/contracts/adapters/kodiak/KodiakIslandGatewayAdapter.sol";

        bytecodes[1].contractType = "ADAPTER::MELLOW_ERC4626_VAULT";
        bytecodes[1].version = 3_12;
        bytecodes[1].initCode = type(Mellow4626VaultAdapter).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/0d992f9d01f4f936b13ba242e7b6ffaf2a88a976/contracts/adapters/mellow/Mellow4626VaultAdapter.sol";

        bytecodes[2].contractType = "ADAPTER::MELLOW_CLAIMER";
        bytecodes[2].version = 3_10;
        bytecodes[2].initCode = type(MellowClaimerAdapter).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/0d992f9d01f4f936b13ba242e7b6ffaf2a88a976/contracts/adapters/mellow/MellowClaimerAdapter.sol";

        bytecodes[3].contractType = "GATEWAY::KODIAK_ISLAND";
        bytecodes[3].version = 3_10;
        bytecodes[3].initCode = type(KodiakIslandGateway).creationCode;
        bytecodes[3].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/0d992f9d01f4f936b13ba242e7b6ffaf2a88a976/contracts/helpers/kodiak/KodiakIslandGateway.sol";

        bytecodes[4].contractType = "PHANTOM_TOKEN::MELLOW_WITHDRAWAL";
        bytecodes[4].version = 3_11;
        bytecodes[4].initCode = type(MellowWithdrawalPhantomToken).creationCode;
        bytecodes[4].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/0d992f9d01f4f936b13ba242e7b6ffaf2a88a976/contracts/helpers/mellow/MellowWithdrawalPhantomToken.sol";

        bytecodes[5].contractType = "PRICE_FEED::KODIAK_ISLAND";
        bytecodes[5].version = 3_10;
        bytecodes[5].initCode = type(KodiakIslandPriceFeed).creationCode;
        bytecodes[5].source =
            "https://github.com/Gearbox-protocol/oracles-v3/blob/4a78b197659ca75de05c8be6c7d87bd54a64504a/contracts/oracles/kodiak/KodiakIslandPriceFeed.sol";
    }
}
