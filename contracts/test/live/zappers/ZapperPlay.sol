// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {WETHZapper} from "../../../zappers/WETHZapper.sol";
import {NetworkDetector} from "@gearbox-protocol/sdk-gov/contracts/NetworkDetector.sol";
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

address constant ap = 0x0Bf1626d4925F8A872801968be11c052862AC2D3;

contract ZapperTest is Test {
    uint256 chainId;
    WETHZapper wethZapper;

    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor() {
        NetworkDetector nd = new NetworkDetector();
        chainId = nd.chainId();
    }

    modifier liveTestOnly() {
        if (chainId == 1) {
            _;
        }
    }

    function setUp() public liveTestOnly {
        wethZapper = new WETHZapper(0x9357C9b42b9a555fCcF94cA5C702d72782865B71);
    }

    function test_weth_zapper() public liveTestOnly {
        console.log("Allowance", IERC20(weth).allowance(address(wethZapper), wethZapper.pool()));
        vm.prank(USER);
        wethZapper.deposit{value: 10 ether}(USER);
    }
}
