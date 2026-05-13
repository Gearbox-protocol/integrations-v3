// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Bytecode} from "@gearbox-protocol/permissionless/contracts/interfaces/Types.sol";
import {UploadBytecode} from "@gearbox-protocol/permissionless/script/UploadBytecode.sol";

import {SecuritizeOnRampAdapter} from "../../contracts/adapters/securitize/SecuritizeOnRampAdapter.sol";
import {
    SecuritizeRedemptionGatewayAdapter
} from "../../contracts/adapters/securitize/SecuritizeRedemptionGatewayAdapter.sol";
import {SecuritizeLiquidator} from "../../contracts/helpers/securitize/SecuritizeLiquidator.sol";
import {SecuritizeRedemptionGateway} from "../../contracts/helpers/securitize/SecuritizeRedemptionGateway.sol";
import {
    SecuritizeRedemptionPhantomToken
} from "../../contracts/helpers/securitize/SecuritizeRedemptionPhantomToken.sol";
import {ERC4626UnderlyingZapper} from "../../contracts/zappers/ERC4626UnderlyingZapper.sol";

contract Upload_2026_05_11_Integrations is UploadBytecode {
    function _getContracts() internal pure override returns (Bytecode[] memory bytecodes) {
        bytecodes = new Bytecode[](6);
        bytecodes[0].contractType = "ADAPTER::SECURITIZE_ONRAMP";
        bytecodes[0].version = 3_10;
        bytecodes[0].initCode = type(SecuritizeOnRampAdapter).creationCode;
        bytecodes[0].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/7531c847ec13acad34df3f35da298fe4fe5fde9e/contracts/adapters/securitize/SecuritizeOnRampAdapter.sol";

        bytecodes[1].contractType = "ADAPTER::SECURITIZE_REDEMPTION";
        bytecodes[1].version = 3_10;
        bytecodes[1].initCode = type(SecuritizeRedemptionGatewayAdapter).creationCode;
        bytecodes[1].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/7531c847ec13acad34df3f35da298fe4fe5fde9e/contracts/adapters/securitize/SecuritizeRedemptionGatewayAdapter.sol";

        bytecodes[2].contractType = "RWA_LIQUIDATOR::SECURITIZE";
        bytecodes[2].version = 3_10;
        bytecodes[2].initCode = type(SecuritizeLiquidator).creationCode;
        bytecodes[2].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/7531c847ec13acad34df3f35da298fe4fe5fde9e/contracts/helpers/securitize/SecuritizeLiquidator.sol";

        bytecodes[3].contractType = "GATEWAY::SECURITIZE_REDEMPTION";
        bytecodes[3].version = 3_10;
        bytecodes[3].initCode = type(SecuritizeRedemptionGateway).creationCode;
        bytecodes[3].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/7531c847ec13acad34df3f35da298fe4fe5fde9e/contracts/helpers/securitize/SecuritizeRedemptionGateway.sol";

        bytecodes[4].contractType = "PHANTOM_TOKEN::SECURITIZE_RD";
        bytecodes[4].version = 3_10;
        bytecodes[4].initCode = type(SecuritizeRedemptionPhantomToken).creationCode;
        bytecodes[4].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/7531c847ec13acad34df3f35da298fe4fe5fde9e/contracts/helpers/securitize/SecuritizeRedemptionPhantomToken.sol";

        bytecodes[5].contractType = "ZAPPER::ERC4626_UNDERLYING";
        bytecodes[5].version = 3_10;
        bytecodes[5].initCode = type(ERC4626UnderlyingZapper).creationCode;
        bytecodes[5].source =
            "https://github.com/Gearbox-protocol/integrations-v3/blob/2e8300fe300a8cb98a39981c8bf21a72c1b2b06e/contracts/zappers/ERC4626UnderlyingZapper.sol";
    }
}
