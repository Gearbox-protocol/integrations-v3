// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

import {UpshiftVaultAdapter} from "../../../adapters/upshift/UpshiftVaultAdapter.sol";
import {UpshiftVaultGateway} from "../../../helpers/upshift/UpshiftVaultGateway.sol";
import {UpshiftVaultWithdrawalPhantomToken} from "../../../helpers/upshift/UpshiftVaultWithdrawalPhantomToken.sol";

import {IERC4626Adapter} from "../../../interfaces/erc4626/IERC4626Adapter.sol";
import {IUpshiftVaultAdapter} from "../../../interfaces/upshift/IUpshiftVaultAdapter.sol";

import {IntegrationsAttachTestBase} from "../IntegrationsAttachTestBase.sol";

contract UpshiftAttachTest is IntegrationsAttachTestBase {
    address constant tBTC = 0x18084fbA666a33d37592fA2633fD49a74DD93a88;
    address constant uptBTC = 0x8AcA0841993ef4C87244d519166e767f49362C21;

    address uptBTCGateway;
    address wduptBTC;

    function setUp() public {
        super._setUp();

        vm.skip(block.chainid != 1, "Not Ethereum mainnet");

        _uploadContract("ADAPTER::UPSHIFT_VAULT", 3_11, type(UpshiftVaultAdapter).creationCode);
        _uploadContract("GATEWAY::UPSHIFT_VAULT", 3_11, type(UpshiftVaultGateway).creationCode);
        _uploadContract("PHANTOM_TOKEN::UPSHIFT_WITHDRAW", 3_10, type(UpshiftVaultWithdrawalPhantomToken).creationCode);

        uptBTCGateway = _deploy("GATEWAY::UPSHIFT_VAULT", 3_10, abi.encode(uptBTC));
        wduptBTC = _deploy("PHANTOM_TOKEN::UPSHIFT_WITHDRAW", 3_10, abi.encode(uptBTC, uptBTCGateway));

        _addToken(tBTC);
        _addToken(uptBTC);
        _addToken(wduptBTC);

        _allowAdapter(creditManager, "UPSHIFT_VAULT", abi.encode(creditManager, uptBTCGateway, wduptBTC));
    }

    function test_upshift() public {}
}
