// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {UpshiftVaultGateway} from "../../contracts/helpers/upshift/UpshiftVaultGateway.sol";

import {KelpLRTDepositPoolAdapter} from "../../contracts/adapters/kelp/KelpLRTDepositPoolAdapter.sol";
import {KelpLRTWithdrawalManagerAdapter} from "../../contracts/adapters/kelp/KelpLRTWithdrawalManagerAdapter.sol";
import {KelpLRTDepositPoolGateway} from "../../contracts/helpers/kelp/KelpLRTDepositPoolGateway.sol";
import {KelpLRTWithdrawalManagerGateway} from "../../contracts/helpers/kelp/KelpLRTWithdrawalManagerGateway.sol";
import {KelpLRTWithdrawalPhantomToken} from "../../contracts/helpers/kelp/KelpLRTWithdrawalPhantomToken.sol";

contract Upload_2026_01_13_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](5);
        bytecodes[0].contractType = "ADAPTER::KELP_DEPOSIT_POOL";
        bytecodes[0].version = 3_10;
        bytecodes[0].initCode = type(KelpLRTDepositPoolAdapter).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/047163d347febcfdd09a609edfe192355a6ba529/contracts/adapters/kelp/KelpLRTDepositPoolAdapter.sol";

        bytecodes[1].contractType = "ADAPTER::KELP_WITHDRAWAL";
        bytecodes[1].version = 3_10;
        bytecodes[1].initCode = type(KelpLRTWithdrawalManagerAdapter).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/047163d347febcfdd09a609edfe192355a6ba529/contracts/adapters/kelp/KelpLRTWithdrawalManagerAdapter.sol";

        bytecodes[2].contractType = "GATEWAY::KELP_DEPOSIT_POOL";
        bytecodes[2].version = 3_10;
        bytecodes[2].initCode = type(KelpLRTDepositPoolGateway).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/047163d347febcfdd09a609edfe192355a6ba529/contracts/helpers/kelp/KelpLRTDepositPoolGateway.sol";

        bytecodes[3].contractType = "GATEWAY::KELP_WITHDRAWAL";
        bytecodes[3].version = 3_10;
        bytecodes[3].initCode = type(KelpLRTWithdrawalManagerGateway).creationCode;
        bytecodes[3].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/047163d347febcfdd09a609edfe192355a6ba529/contracts/helpers/kelp/KelpLRTWithdrawalManagerGateway.sol";

        bytecodes[4].contractType = "PHANTOM_TOKEN::KELP_WITHDRAWAL";
        bytecodes[4].version = 3_10;
        bytecodes[4].initCode = type(KelpLRTWithdrawalPhantomToken).creationCode;
        bytecodes[4].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/047163d347febcfdd09a609edfe192355a6ba529/contracts/helpers/kelp/KelpLRTWithdrawalPhantomToken.sol";
    }
}
