// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {ConvexV1BaseRewardPoolAdapter} from "../../contracts/integrations/convex/ConvexV1_BaseRewardPool.sol";
import {ERC4626Adapter} from "../../contracts/integrations/erc4626/ERC4626Adapter.sol";
import {ERC4626Zapper} from "../../contracts/zappers/ERC4626Zapper.sol";
import {StakedERC4626Zapper} from "../../contracts/zappers/StakedERC4626Zapper.sol";

contract Upload_2025_07_29_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](4);
        bytecodes[0].contractType = "ADAPTER::CVX_V1_BASE_REWARD_POOL";
        bytecodes[0].version = 3_11;
        bytecodes[0].initCode = type(ConvexV1BaseRewardPoolAdapter).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/883aad9cffe8ea77258f806b6ebbf34a013d9348/contracts/adapters/convex/ConvexV1_BaseRewardPool.sol";

        bytecodes[1].contractType = "ADAPTER::ERC4626_VAULT";
        bytecodes[1].version = 3_12;
        bytecodes[1].initCode = type(ERC4626Adapter).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/883aad9cffe8ea77258f806b6ebbf34a013d9348/contracts/adapters/erc4626/ERC4626Adapter.sol";

        bytecodes[2].contractType = "ZAPPER::ERC4626";
        bytecodes[2].version = 3_10;
        bytecodes[2].initCode = type(ERC4626Zapper).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/883aad9cffe8ea77258f806b6ebbf34a013d9348/contracts/zappers/ERC4626Zapper.sol";

        bytecodes[3].contractType = "ZAPPER::STAKED_ERC4626";
        bytecodes[3].version = 3_10;
        bytecodes[3].initCode = type(StakedERC4626Zapper).creationCode;
        bytecodes[3].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/883aad9cffe8ea77258f806b6ebbf34a013d9348/contracts/zappers/StakedERC4626Zapper.sol";
    }
}
