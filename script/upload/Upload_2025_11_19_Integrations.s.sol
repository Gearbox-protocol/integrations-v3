// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {UniswapV4Adapter} from "../../contracts/integrations/uniswap/UniswapV4.sol";
import {UniswapV4Gateway} from "../../contracts/integrations/uniswap/UniswapV4Gateway.sol";

contract Upload_2025_11_19_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](2);

        bytecodes[0].contractType = "ADAPTER::UNISWAP_V4_GATEWAY";
        bytecodes[0].version = 3_10;
        bytecodes[0].initCode = type(UniswapV4Adapter).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/b3cc54453225b0f163aaa48f812dbd5ff5c9a148/contracts/adapters/uniswap/UniswapV4.sol";

        bytecodes[1].contractType = "GATEWAY::UNISWAP_V4";
        bytecodes[1].version = 3_10;
        bytecodes[1].initCode = type(UniswapV4Gateway).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/b3cc54453225b0f163aaa48f812dbd5ff5c9a148/contracts/helpers/uniswap/UniswapV4Gateway.sol";
    }
}
