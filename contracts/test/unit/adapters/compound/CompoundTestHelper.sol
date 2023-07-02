// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {
    CONFIGURATOR,
    DAI_ACCOUNT_AMOUNT,
    USDC_EXCHANGE_AMOUNT,
    USER,
    WETH_EXCHANGE_AMOUNT
} from "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import {CEtherGateway} from "../../../../adapters/compound/CEtherGateway.sol";
import {CompoundPriceFeed} from "../../../../oracles/compound/CompoundPriceFeed.sol";

import {Tokens} from "../../../config/Tokens.sol";
import {CErc20Mock} from "../../../mocks/integrations/compound/CErc20Mock.sol";
import {CEtherMock} from "../../../mocks/integrations/compound/CEtherMock.sol";
import {AdapterTestHelper} from "../AdapterTestHelper.sol";

contract CompoundTestHelper is AdapterTestHelper {
    // underlying tokens
    address weth;
    address usdc;
    address dai;

    // cTokens
    address ceth;
    address cusdc;
    address cdai;

    // cETH gateway
    CEtherGateway gateway;

    function _setupCompoundSuite() internal {
        _setUp();

        tokenTestSuite.mint(Tokens.DAI, USER, DAI_ACCOUNT_AMOUNT);

        usdc = tokenTestSuite.addressOf(Tokens.USDC);
        weth = tokenTestSuite.addressOf(Tokens.WETH);
        dai = tokenTestSuite.addressOf(Tokens.DAI);

        // setup cTokens, top them up with some liquidity
        ceth = address(new CEtherMock(0.02 ether, 0.05 ether));
        cusdc = address(new CErc20Mock(usdc, 0.02 ether, 0.025 ether));
        cdai = address(new CErc20Mock(dai, 0.02 ether, 0.02 ether));
        vm.deal(ceth, 100e18);
        tokenTestSuite.mint(Tokens.USDC, cusdc, 100_000e6);
        tokenTestSuite.mint(Tokens.DAI, cdai, 100_000e18);

        // setup cETH gateway
        gateway = new CEtherGateway(weth, address(ceth));

        vm.label(ceth, "cETH");
        vm.label(cusdc, "cUSDC");
        vm.label(cdai, "cDAI");
        vm.label(address(gateway), "cETH_GATEWAY");

        vm.startPrank(CONFIGURATOR);
        // add price feeds for cTokens to the oracle
        cft.priceOracle().addPriceFeed(
            ceth,
            address(new CompoundPriceFeed(address(cft.addressProvider()), ceth, cft.priceOracle().priceFeeds(weth)))
        );
        cft.priceOracle().addPriceFeed(
            cusdc,
            address(new CompoundPriceFeed(address(cft.addressProvider()), cusdc, cft.priceOracle().priceFeeds(usdc)))
        );

        // enable cTokens as collateral tokens in the credit manager
        CreditConfiguratorV3.addCollateralToken(ceth, 8300);
        CreditConfiguratorV3.addCollateralToken(cusdc, 8300);
        vm.stopPrank();
    }

    function _openAccountWithToken(Tokens token)
        internal
        returns (address creditAccount, address underlying, address cToken, uint256 balance)
    {
        (creditAccount,) = _openTestCreditAccount();
        (underlying, cToken, balance) = _tokenInfo(token);

        tokenTestSuite.mint(underlying, USER, balance);

        tokenTestSuite.approve(underlying, USER, address(CreditManagerV3), balance);
        vm.prank(USER);
        creditFacade.addCollateral(USER, underlying, balance);
    }

    function _openAccountWithCToken(Tokens token)
        internal
        returns (address creditAccount, address underlying, address cToken, uint256 balance)
    {
        (creditAccount,) = _openTestCreditAccount();
        uint256 amount;
        (underlying, cToken, amount) = _tokenInfo(token);

        tokenTestSuite.mint(underlying, USER, amount);
        if (token == Tokens.WETH) {
            tokenTestSuite.approve(underlying, USER, address(gateway), amount);
            vm.prank(USER);
            gateway.mint(amount);
        } else {
            tokenTestSuite.approve(underlying, USER, cToken, amount);
            vm.prank(USER);
            CErc20Mock(cToken).mint(amount);
        }

        balance = tokenTestSuite.balanceOf(cToken, USER);
        tokenTestSuite.approve(cToken, USER, address(CreditManagerV3), balance);
        vm.prank(USER);
        creditFacade.addCollateral(USER, cToken, balance);
    }

    function _tokenInfo(Tokens token) internal view returns (address underlying, address cToken, uint256 amount) {
        if (token == Tokens.USDC) {
            return (usdc, cusdc, USDC_EXCHANGE_AMOUNT);
        } else if (token == Tokens.WETH) {
            return (weth, ceth, WETH_EXCHANGE_AMOUNT);
        }
        revert("Token must be one of USDC or WETH");
    }
}
