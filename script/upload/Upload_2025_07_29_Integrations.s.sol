// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {ConvexV1BaseRewardPoolAdapter} from "../../contracts/adapters/convex/ConvexV1_BaseRewardPool.sol";
import {ERC4626Adapter} from "../../contracts/adapters/erc4626/ERC4626Adapter.sol";
import {UpshiftVaultAdapter} from "../../contracts/adapters/upshift/UpshiftVaultAdapter.sol";
import {UpshiftVaultGateway} from "../../contracts/helpers/upshift/UpshiftVaultGateway.sol";
import {UpshiftVaultWithdrawalPhantomToken} from
    "../../contracts/helpers/upshift/UpshiftVaultWithdrawalPhantomToken.sol";
import {ERC4626Zapper} from "../../contracts/zappers/ERC4626Zapper.sol";
import {StakedERC4626Zapper} from "../../contracts/zappers/StakedERC4626Zapper.sol";

contract Upload_2025_07_29_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](7);
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

        bytecodes[2].contractType = "ADAPTER::UPSHIFT_VAULT";
        bytecodes[2].version = 3_10;
        bytecodes[2].initCode = type(UpshiftVaultAdapter).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/883aad9cffe8ea77258f806b6ebbf34a013d9348/contracts/adapters/upshift/UpshiftVaultAdapter.sol";

        bytecodes[3].contractType = "GATEWAY::UPSHIFT_VAULT";
        bytecodes[3].version = 3_10;
        bytecodes[3].initCode = type(UpshiftVaultGateway).creationCode;
        bytecodes[3].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/883aad9cffe8ea77258f806b6ebbf34a013d9348/contracts/helpers/upshift/UpshiftVaultGateway.sol";

        bytecodes[4].contractType = "PHANTOM_TOKEN::UPSHIFT_WITHDRAW";
        bytecodes[4].version = 3_10;
        bytecodes[4].initCode = type(UpshiftVaultWithdrawalPhantomToken).creationCode;
        bytecodes[4].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/883aad9cffe8ea77258f806b6ebbf34a013d9348/contracts/helpers/upshift/UpshiftVaultWithdrawalPhantomToken.sol";

        bytecodes[5].contractType = "ZAPPER::ERC4626";
        bytecodes[5].version = 3_10;
        bytecodes[5].initCode = type(ERC4626Zapper).creationCode;
        bytecodes[5].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/883aad9cffe8ea77258f806b6ebbf34a013d9348/contracts/zappers/ERC4626Zapper.sol";

        bytecodes[6].contractType = "ZAPPER::STAKED_ERC4626";
        bytecodes[6].version = 3_10;
        bytecodes[6].initCode = type(StakedERC4626Zapper).creationCode;
        bytecodes[6].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/883aad9cffe8ea77258f806b6ebbf34a013d9348/contracts/zappers/StakedERC4626Zapper.sol";
    }
}
