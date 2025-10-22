// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {BalancerV3RouterAdapter} from "../../contracts/adapters/balancer/BalancerV3RouterAdapter.sol";
import {BalancerV3WrapperAdapter} from "../../contracts/adapters/balancer/BalancerV3WrapperAdapter.sol";
import {PendleRouterAdapter} from "../../contracts/adapters/pendle/PendleRouterAdapter.sol";
import {BalancerV3RouterGateway} from "../../contracts/helpers/balancer/BalancerV3RouterGateway.sol";

contract Upload_2025_10_22_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](4);
        bytecodes[0].contractType = "ADAPTER::BALANCER_V3_ROUTER";
        bytecodes[0].version = 3_11;
        bytecodes[0].initCode = type(BalancerV3RouterAdapter).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/44dfdca1edba59d0183a4cf0416712d3ee1e847e/contracts/adapters/balancer/BalancerV3RouterAdapter.sol";

        bytecodes[1].contractType = "ADAPTER::BALANCER_V3_WRAPPER";
        bytecodes[1].version = 3_10;
        bytecodes[1].initCode = type(BalancerV3WrapperAdapter).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/44dfdca1edba59d0183a4cf0416712d3ee1e847e/contracts/adapters/balancer/BalancerV3WrapperAdapter.sol";

        bytecodes[2].contractType = "ADAPTER::PENDLE_ROUTER";
        bytecodes[2].version = 3_11;
        bytecodes[2].initCode = type(PendleRouterAdapter).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/44dfdca1edba59d0183a4cf0416712d3ee1e847e/contracts/adapters/pendle/PendleRouterAdapter.sol";

        bytecodes[3].contractType = "GATEWAY::BALANCER_V3";
        bytecodes[3].version = 3_11;
        bytecodes[3].initCode = type(BalancerV3RouterGateway).creationCode;
        bytecodes[3].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/44dfdca1edba59d0183a4cf0416712d3ee1e847e/contracts/helpers/balancer/BalancerV3RouterGateway.sol";
    }
}
