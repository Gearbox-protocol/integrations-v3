// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {PoolV3} from "@gearbox-protocol/core-v3/contracts/pool/PoolV3.sol";
import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";

import {IZapper} from "../../interfaces/zappers/IZapper.sol";

import {UnderlyingDepositZapper} from "../../zappers/UnderlyingDepositZapper.sol";
import {UnderlyingFarmingZapper} from "../../zappers/UnderlyingFarmingZapper.sol";
import {WETHDepositZapper} from "../../zappers/WETHDepositZapper.sol";
import {WETHFarmingZapper} from "../../zappers/WETHFarmingZapper.sol";
import {WstETHDepositZapper} from "../../zappers/WstETHDepositZapper.sol";
import {WstETHFarmingZapper} from "../../zappers/WstETHFarmingZapper.sol";

import {ZapperRegister} from "./ZapperRegister.sol";
import {LiveTestHelper} from "./LiveTestHelper.sol";

contract ZapperLiveTestHelper is LiveTestHelper {
    ZapperRegister zapperRegister;
    mapping(address => address) farmingPools;
    mapping(address => address) legacyPools;

    modifier attachOrLiveZapperTest() {
        // Setting `--chain-id` to 1337 or 31337 will make `NetworkDetector` try to deduce chain id
        // by calling known contracts on various networks, and set `chainId` to the deduced value.
        // If it fails, the value stays equal to the passed one, and the test can be skipped.
        if (chainId == 1337 || chainId == 31337) return;

        // Either `ATTACH_ZAPPER_REGISTER` or `LIVE_TEST_CONFIG` must be specified.
        // The former allows to test existing deployed zappers, while the latter allows to create a new pool and test a zappers for it.
        // If `ATTACH_ZAPPER_REGISTER` is specified, then `ATTACH_POOL` must also be specified
        address attachedZapperRegister = vm.envOr("ATTACH_ZAPPER_REGISTER", address(0));
        if (attachedZapperRegister != address(0)) {
            address acl = ZapperRegister(attachedZapperRegister).acl();
            address contractsRegister = ZapperRegister(attachedZapperRegister).contractsRegister();

            _attachState();

            // By default, attach tests are run for already deployed zappers.
            // To test the ones that are not deployed yet, set `REDEPLOY_ZAPPERS` to `true`.
            bool redeployZappers = vm.envOr("REDEPLOY_ZAPPERS", false);
            if (redeployZappers) {
                zapperRegister = new ZapperRegister(acl, contractsRegister);
            } else {
                zapperRegister = ZapperRegister(attachedZapperRegister);
            }

            _attachPool(vm.envAddress("ATTACH_POOL"));
            if (redeployZappers) _deployZappers(address(pool));
            _;
        } else {
            // Deploy the system from scratch using given config.
            _setupCore();
            _attachState();
            zapperRegister = new ZapperRegister(address(acl), address(cr));
            _deployPool(getDeployConfig(vm.envString("LIVE_TEST_CONFIG")));
            _deployZappers(address(pool));
            _;
        }
    }

    function _getZapper(address pool, address tokenIn, address tokenOut) internal view returns (address) {
        // TODO: Assumes that (tokenIn, tokenOut) uniquely identify a zapper, which is not necessarily true.
        address[] memory zappers = zapperRegister.zappers(pool);
        for (uint256 i; i < zappers.length; ++i) {
            if (IZapper(zappers[i]).tokenIn() == tokenIn && IZapper(zappers[i]).tokenOut() == tokenOut) {
                return zappers[i];
            }
        }
        return address(0);
    }

    function _deployZappers(address pool) internal {
        address underlying = PoolV3(pool).underlyingToken();
        address farmingPool = farmingPools[pool];

        // Underlying zapper
        try IERC20Permit(underlying).DOMAIN_SEPARATOR() returns (bytes32) {
            zapperRegister.addZapper(address(new UnderlyingDepositZapper(pool)));
        } catch {}
        if (farmingPool != address(0)) {
            zapperRegister.addZapper(address(new UnderlyingFarmingZapper(pool, farmingPool)));
        }

        // WETH zapper
        if (underlying == tokenTestSuite.addressOf(TOKEN_WETH)) {
            zapperRegister.addZapper(address(new WETHDepositZapper(pool)));
            if (farmingPool != address(0)) {
                zapperRegister.addZapper(address(new WETHFarmingZapper(pool, farmingPool)));
            }
        }

        // wstETH zapper
        if (underlying == tokenTestSuite.addressOf(TOKEN_wstETH) && tokenTestSuite.addressOf(TOKEN_STETH) != address(0))
        {
            zapperRegister.addZapper(address(new WstETHDepositZapper(pool)));
            if (farmingPool != address(0)) {
                zapperRegister.addZapper(address(new WstETHFarmingZapper(pool, farmingPool)));
            }
        }
    }

    function _attachState() internal {
        // TODO: Would be nice to have this information stored in sdk-gov instead.
        // Not exactly clear how to test in case farming pool is not deployed yet.
        farmingPools[tokenTestSuite.addressOf(TOKEN_dWETHV3)] = tokenTestSuite.addressOf(TOKEN_sdWETHV3);
        farmingPools[tokenTestSuite.addressOf(TOKEN_dWBTCV3)] = tokenTestSuite.addressOf(TOKEN_sdWBTCV3);
        farmingPools[tokenTestSuite.addressOf(TOKEN_dUSDCV3)] = tokenTestSuite.addressOf(TOKEN_sdUSDCV3);
        farmingPools[tokenTestSuite.addressOf(TOKEN_dUSDTV3)] = tokenTestSuite.addressOf(TOKEN_sdUSDTV3);
        farmingPools[tokenTestSuite.addressOf(TOKEN_dDAIV3)] = tokenTestSuite.addressOf(TOKEN_sdDAIV3);
        farmingPools[tokenTestSuite.addressOf(TOKEN_dGHOV3)] = tokenTestSuite.addressOf(TOKEN_sdGHOV3);

        legacyPools[tokenTestSuite.addressOf(TOKEN_DAI)] = _getLegacyPool(TOKEN_DAI);
        legacyPools[tokenTestSuite.addressOf(TOKEN_WETH)] = _getLegacyPool(TOKEN_WETH);
        legacyPools[tokenTestSuite.addressOf(TOKEN_WBTC)] = _getLegacyPool(TOKEN_WBTC);
        legacyPools[tokenTestSuite.addressOf(TOKEN_USDC)] = _getLegacyPool(TOKEN_USDC);
        legacyPools[tokenTestSuite.addressOf(TOKEN_FRAX)] = _getLegacyPool(TOKEN_FRAX);
        legacyPools[tokenTestSuite.addressOf(TOKEN_wstETH)] = _getLegacyPool(TOKEN_wstETH);
    }

    function _getLegacyPool(uint256 t) internal view returns (address) {
        address token = tokenTestSuite.addressOf(t);
        if (token == address(0)) return address(0);
        (bool success, bytes memory result) = token.staticcall(abi.encodeWithSignature("owner()"));
        if (!success) {
            (success, result) = token.staticcall(abi.encodeWithSignature("poolService()"));
            if (!success) return address(0);
        }
        return abi.decode(result, (address));
    }
}
