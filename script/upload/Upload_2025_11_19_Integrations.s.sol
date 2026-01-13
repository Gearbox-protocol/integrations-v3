// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {InfinifiGatewayAdapter} from "../../contracts/adapters/infinifi/InfinifiGatewayAdapter.sol";
import {InfinifiUnwindingGatewayAdapter} from "../../contracts/adapters/infinifi/InfinifiUnwindingGatewayAdapter.sol";
import {UniswapV4Adapter} from "../../contracts/adapters/uniswap/UniswapV4.sol";
import {InfinifiUnwindingGateway} from "../../contracts/helpers/infinifi/InfinifiUnwindingGateway.sol";
import {InfinifiUnwindingPhantomToken} from "../../contracts/helpers/infinifi/InfinifiUnwindingPhantomToken.sol";
import {UniswapV4Gateway} from "../../contracts/helpers/uniswap/UniswapV4Gateway.sol";

contract Upload_2025_11_19_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](6);

        bytecodes[0].contractType = "ADAPTER::INFINIFI_GATEWAY";
        bytecodes[0].version = 3_10;
        bytecodes[0].initCode = type(InfinifiGatewayAdapter).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/b3cc54453225b0f163aaa48f812dbd5ff5c9a148/contracts/adapters/infinifi/InfinifiGatewayAdapter.sol";

        bytecodes[1].contractType = "ADAPTER::INFINIFI_UNWINDING";
        bytecodes[1].version = 3_10;
        bytecodes[1].initCode = type(InfinifiUnwindingGatewayAdapter).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/b3cc54453225b0f163aaa48f812dbd5ff5c9a148/contracts/adapters/infinifi/InfinifiUnwindingGatewayAdapter.sol";

        bytecodes[2].contractType = "ADAPTER::UNISWAP_V4_GATEWAY";
        bytecodes[2].version = 3_10;
        bytecodes[2].initCode = type(UniswapV4Adapter).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/b3cc54453225b0f163aaa48f812dbd5ff5c9a148/contracts/adapters/uniswap/UniswapV4.sol";

        bytecodes[3].contractType = "GATEWAY::INFINIFI_UNWINDING";
        bytecodes[3].version = 3_10;
        bytecodes[3].initCode = type(InfinifiUnwindingGateway).creationCode;
        bytecodes[3].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/b3cc54453225b0f163aaa48f812dbd5ff5c9a148/contracts/helpers/infinifi/InfinifiUnwindingGateway.sol";

        bytecodes[4].contractType = "PHANTOM_TOKEN::INFINIFI_UNWIND";
        bytecodes[4].version = 3_10;
        bytecodes[4].initCode = type(InfinifiUnwindingPhantomToken).creationCode;
        bytecodes[4].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/b3cc54453225b0f163aaa48f812dbd5ff5c9a148/contracts/helpers/infinifi/InfinifiUnwindingPhantomToken.sol";

        bytecodes[5].contractType = "GATEWAY::UNISWAP_V4";
        bytecodes[5].version = 3_10;
        bytecodes[5].initCode = type(UniswapV4Gateway).creationCode;
        bytecodes[5].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/b3cc54453225b0f163aaa48f812dbd5ff5c9a148/contracts/helpers/uniswap/UniswapV4Gateway.sol";
    }
}
