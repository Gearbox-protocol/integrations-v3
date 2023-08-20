// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/PercentageMath.sol";
import {
    CONFIGURATOR,
    DAI_ACCOUNT_AMOUNT,
    USDC_EXCHANGE_AMOUNT,
    USER,
    WETH_EXCHANGE_AMOUNT
} from "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import {WrappedATokenV2} from "@gearbox-protocol/oracles-v3/contracts/tokens/aave/WrappedATokenV2.sol";
import {IAToken} from "../../../../integrations/aave/IAToken.sol";

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";
import {ATokenMock} from "../../../mocks/integrations/aave/ATokenMock.sol";
import {LendingPoolMock} from "../../../mocks/integrations/aave/LendingPoolMock.sol";

import {WrappedAaveV2PriceFeed} from "@gearbox-protocol/oracles-v3/contracts/oracles/aave/WrappedAaveV2PriceFeed.sol";
import {AdapterTestHelper} from "../AdapterTestHelper.sol";

contract AaveTestHelper is AdapterTestHelper {
    LendingPoolMock public lendingPool;

    // underlying tokens
    address dai;
    address usdc;

    // aTokens
    address aDai;
    address aUsdc;
    address aWeth;

    // waTokens
    address waDai;
    address waUsdc;
    address waWeth;

    function _setupAaveSuite(bool withWrappers) internal {
        _setUp();

        tokenTestSuite.mint(Tokens.DAI, USER, DAI_ACCOUNT_AMOUNT);

        dai = tokenTestSuite.addressOf(Tokens.DAI);
        usdc = tokenTestSuite.addressOf(Tokens.USDC);
        weth = tokenTestSuite.addressOf(Tokens.WETH);

        // setup the lending pool and aTokens
        lendingPool = new LendingPoolMock();
        aDai = lendingPool.addReserve(dai, 100 * RAY / PERCENTAGE_FACTOR);
        aUsdc = lendingPool.addReserve(usdc, 200 * RAY / PERCENTAGE_FACTOR);
        aWeth = lendingPool.addReserve(weth, 500 * RAY / PERCENTAGE_FACTOR);

        // seed reserves with some tokens to pay interest
        tokenTestSuite.mint(Tokens.DAI, aDai, 1_000_000e18);
        tokenTestSuite.mint(Tokens.USDC, aUsdc, 1_000_000e6);
        tokenTestSuite.mint(Tokens.WETH, aWeth, 1_000e18);

        vm.label(address(lendingPool), "LENDING_POOL_MOCK");
        vm.label(aDai, "aDAI");
        vm.label(aUsdc, "aUSDC");
        vm.label(aWeth, "aWETH");

        vm.startPrank(CONFIGURATOR);
        // add price feeds for aTokens to the oracle (they are the same as underlying oracles)
        priceOracle.setPriceFeed(aWeth, priceOracle.priceFeeds(weth), 0);
        priceOracle.setPriceFeed(aUsdc, priceOracle.priceFeeds(usdc), 0);

        // enable aTokens as collateral tokens in the credit manager
        creditConfigurator.addCollateralToken(aWeth, 8300);
        creditConfigurator.addCollateralToken(aUsdc, 8300);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);

        if (withWrappers) _setupWrappers();
    }

    function _setupWrappers() internal {
        waDai = address(new WrappedATokenV2(aDai));
        waUsdc = address(new WrappedATokenV2(aUsdc));
        waWeth = address(new WrappedATokenV2(aWeth));
        vm.label(waDai, "waDAI");
        vm.label(waUsdc, "waUSDC");
        vm.label(waWeth, "waWETH");

        vm.startPrank(CONFIGURATOR);
        // add price feeds for waTokens to the oracle
        priceOracle.setPriceFeed(
            waWeth,
            address(
                new WrappedAaveV2PriceFeed(address(addressProvider), waWeth, priceOracle.priceFeeds(weth), 48 hours)
            ),
            0
        );
        priceOracle.setPriceFeed(
            waUsdc,
            address(
                new WrappedAaveV2PriceFeed(address(addressProvider), waUsdc, priceOracle.priceFeeds(usdc), 48 hours)
            ),
            0
        );

        // enable waTokens as collateral tokens in the credit manager
        creditConfigurator.addCollateralToken(waWeth, 8300);
        creditConfigurator.addCollateralToken(waUsdc, 8300);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);
    }

    function _openAccountWithToken(Tokens token) internal returns (address creditAccount, uint256 balance) {
        (creditAccount,) = _openTestCreditAccount();
        (address underlying,,, uint256 amount) = _tokenInfo(token);
        balance = amount;

        tokenTestSuite.mint(underlying, USER, balance);

        tokenTestSuite.approve(underlying, USER, address(creditManager), balance);
        vm.prank(USER);
        // creditFacade.addCollateral(USER, underlying, balance);
    }

    function _openAccountWithAToken(Tokens token) internal returns (address creditAccount, uint256 balance) {
        (creditAccount,) = _openTestCreditAccount();
        (address underlying, address aToken,, uint256 amount) = _tokenInfo(token);
        balance = amount;

        tokenTestSuite.mint(underlying, USER, balance);

        tokenTestSuite.approve(underlying, USER, address(lendingPool), balance);
        vm.prank(USER);
        lendingPool.deposit(underlying, balance, address(USER), 0);

        tokenTestSuite.approve(aToken, USER, address(creditManager), balance);
        vm.prank(USER);
        // creditFacade.addCollateral(USER, aToken, balance);
    }

    function _openAccountWithWAToken(Tokens token) internal returns (address creditAccount, uint256 balance) {
        (creditAccount,) = _openTestCreditAccount();
        (address underlying,, address waToken, uint256 amount) = _tokenInfo(token);

        tokenTestSuite.mint(token, USER, amount);

        tokenTestSuite.approve(underlying, USER, waToken, amount);
        vm.prank(USER);
        balance = WrappedATokenV2(waToken).depositUnderlying(amount);

        tokenTestSuite.approve(waToken, USER, address(creditManager), balance);
        vm.prank(USER);
        // creditFacade.addCollateral(USER, waToken, balance);
    }

    function _tokenInfo(Tokens token)
        internal
        view
        returns (address underlying, address aToken, address waToken, uint256 amount)
    {
        if (token == Tokens.USDC) {
            return (usdc, aUsdc, waUsdc, USDC_EXCHANGE_AMOUNT);
        } else if (token == Tokens.WETH) {
            return (weth, aWeth, waWeth, WETH_EXCHANGE_AMOUNT);
        }
        revert("Token must be one of USDC or WETH");
    }
}
