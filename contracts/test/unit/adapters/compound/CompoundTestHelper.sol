// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {
    CONFIGURATOR,
    DAI_ACCOUNT_AMOUNT,
    USDC_EXCHANGE_AMOUNT,
    USER,
    WETH_EXCHANGE_AMOUNT
} from "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

import {CEtherGateway} from "../../../../helpers/compound/CompoundV2_CEtherGateway.sol";

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";
import {CErc20Mock} from "../../../mocks/integrations/compound/CErc20Mock.sol";
import {CEtherMock} from "../../../mocks/integrations/compound/CEtherMock.sol";
import {AdapterTestHelper} from "../AdapterTestHelper.sol";
import {CompoundV2PriceFeed} from "@gearbox-protocol/oracles-v3/contracts/oracles/compound/CompoundV2PriceFeed.sol";

contract CompoundTestHelper is AdapterTestHelper {
    // underlying tokens

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
        priceOracle.setPriceFeed(
            ceth,
            address(new CompoundV2PriceFeed(address(addressProvider), ceth, priceOracle.priceFeeds(weth), 48 hours)),
            0
        );
        priceOracle.setPriceFeed(
            cusdc,
            address(new CompoundV2PriceFeed(address(addressProvider), cusdc, priceOracle.priceFeeds(usdc), 48 hours)),
            0
        );

        // enable cTokens as collateral tokens in the credit manager
        creditConfigurator.addCollateralToken(ceth, 8300);
        creditConfigurator.addCollateralToken(cusdc, 8300);
        vm.stopPrank();
    }

    function _openAccountWithToken(Tokens token)
        internal
        returns (address creditAccount, address underlying, address cToken, uint256 balance)
    {
        (creditAccount,) = _openTestCreditAccount();
        (underlying, cToken, balance) = _tokenInfo(token);

        tokenTestSuite.mint(underlying, USER, balance);

        tokenTestSuite.approve(underlying, USER, address(creditManager), balance);
        vm.prank(USER);
        // creditFacade.addCollateral(USER, underlying, balance);
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
        tokenTestSuite.approve(cToken, USER, address(creditManager), balance);
        vm.prank(USER);
        // creditFacade.addCollateral(USER, cToken, balance);
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
