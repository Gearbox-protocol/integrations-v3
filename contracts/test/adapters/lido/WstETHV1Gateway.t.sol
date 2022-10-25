// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { PoolService } from "@gearbox-protocol/core-v2/contracts/pool/PoolService.sol";
import { WstETHGateway } from "../../../adapters/lido/WstETHGateway.sol";

import { IwstETHGateWay } from "../../../integrations/lido/IwstETHGateway.sol";
import { WstETHV1Mock } from "../../mocks/integrations/WstETHV1Mock.sol";

import { ZeroAddressException } from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

// TEST
import "../../lib/constants.sol";
import { Tokens, TokensTestSuite } from "../../suites/TokensTestSuite.sol";

import { PERCENTAGE_FACTOR } from "@gearbox-protocol/core-v2/contracts/libraries/PercentageMath.sol";

import { WstETHPoolSetup } from "../../suites/WstETHPoolSetup.sol";

uint256 constant STETH_PER_TOKEN = (110 * WAD) / 100;

/// @title WstETHV1AdapterTest
/// @notice Designed for unit test purposes only
contract WstETHV1GatewayTest is DSTest {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    PoolService public pool;
    TokensTestSuite public tokenTestSuite;
    WstETHGateway public wstETHGateway;
    WstETHV1Mock public wstETH;

    // STUBB FUNCTIONS
    address public getContractsRegister = address(this);
    address public getACL = address(this);
    address public getTreasuryContract = address(this);
    address public owner = CONFIGURATOR;

    function addPool(address _pool) external {
        pool = PoolService(_pool);
    }

    function isConfigurator(address configurator) external pure returns (bool) {
        return configurator == CONFIGURATOR;
    }

    function isPool(address _pool) external view returns (bool) {
        return _pool == address(pool);
    }

    function setUp() public {
        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{ value: 100 * WAD }();

        new WstETHPoolSetup(
            address(this),
            tokenTestSuite.addressOf(Tokens.wstETH),
            tokenTestSuite,
            CONFIGURATOR
        );

        wstETHGateway = new WstETHGateway(address(pool));

        wstETH = WstETHV1Mock(tokenTestSuite.addressOf(Tokens.wstETH));
        wstETH.setStEthPerToken((WAD * 15) / 10);
    }

    /// @dev [WSTGV1-1]: constructor sets parameters correctly
    function test_WSTGV1_01_constructor_sets_parameters_correctly() public {
        assertEq(
            address(wstETHGateway.wstETH()),
            tokenTestSuite.addressOf(Tokens.wstETH),
            "Incorrect wstETH tokenb "
        );

        assertEq(
            wstETHGateway.stETH(),
            tokenTestSuite.addressOf(Tokens.STETH),
            "Incorrect STETH token"
        );

        assertEq(wstETHGateway.pool(), address(pool), "Incorrect pool tokenb ");

        assertEq(
            IERC20(wstETHGateway.stETH()).allowance(
                address(wstETHGateway),
                address(wstETH)
            ),
            type(uint256).max
        );
    }

    /// @dev [WSTGV1-2]: constructor reverts if needed
    function test_WSTGV1_02_constructor_sets_reverts_if_needed() public {
        evm.expectRevert(ZeroAddressException.selector);
        new WstETHGateway(address(0));

        PoolService pool2 = new PoolService(
            address(this),
            tokenTestSuite.addressOf(Tokens.wstETH),
            address(pool.interestRateModel()),
            pool.expectedLiquidityLimit()
        );

        evm.expectRevert(IwstETHGateWay.NonRegisterPoolException.selector);
        new WstETHGateway(address(pool2));
    }

    /// @dev [WSTGV1-3]: constructor sets parameters correctly
    function test_WSTGV1_03_add_and_remove_liquidity_works_correctly() public {
        tokenTestSuite.mint(Tokens.STETH, USER, 50 * WAD);
        tokenTestSuite.approve(Tokens.STETH, USER, address(wstETHGateway));

        uint256 wstETHexpectedAmount = wstETH.getWstETHByStETH(50 * WAD);

        address dt = pool.dieselToken();

        evm.prank(USER);
        wstETHGateway.addLiquidity(50 * WAD, USER, 0);
        assertEq(
            IERC20(dt).balanceOf(USER),
            wstETHexpectedAmount,
            "Incorrect amount deposited"
        );
        assertEq(
            tokenTestSuite.balanceOf(Tokens.STETH, USER),
            0,
            "INCORRECT BALANCE"
        );

        evm.prank(USER);
        IERC20(dt).approve(address(wstETHGateway), type(uint256).max);

        evm.prank(USER);
        wstETHGateway.removeLiquidity(30 * WAD, USER);

        uint256 expectedAmount = (wstETH.getStETHByWstETH(30 * WAD) *
            (PERCENTAGE_FACTOR - pool.withdrawFee())) / PERCENTAGE_FACTOR;

        assertEq(
            tokenTestSuite.balanceOf(Tokens.STETH, USER),
            expectedAmount,
            "INCORRECT STETH BALANCE"
        );
    }
}
