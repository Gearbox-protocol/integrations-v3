// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {YearnPriceFeed, RANGE_WIDTH} from "../../oracles/yearn/YearnPriceFeed.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/PercentageMath.sol";

// LIBRARIES

// TEST
import "../lib/constants.sol";

// MOCKS
import {YearnV2Mock} from "../mocks/integrations/YearnV2Mock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";

// SUITES
import {TokensTestSuite, Tokens} from "../suites/TokensTestSuite.sol";

// EXCEPTIONS

import {IPriceOracleV2Exceptions} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceOracleV2.sol";

/// @title YearnFeedTest
/// @notice Designed for unit test purposes only
contract YearnFeedTest is Test, ILPPriceFeedExceptions, IPriceOracleV2Exceptions {
    AddressProviderV3ACLMock public addressProvider;
    YearnV2Mock public yearnMock;

    PriceFeedMock public underlyingPf;

    YearnPriceFeed public pf;

    TokensTestSuite tokenTestSuite;

    function setUp() public {
        addressProvider = new AddressProviderV3ACLMock();

        underlyingPf = new PriceFeedMock(1100, 8);

        underlyingPf.setParams(11, 1111, 1112, 11);

        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{value: 100 * WAD}();

        yearnMock = new YearnV2Mock(tokenTestSuite.addressOf(Tokens.DAI));

        vm.prank(CONFIGURATOR);
        yearnMock.setPricePerShare(WAD);

        pf = new YearnPriceFeed(
            address(addressProvider),
            address(yearnMock),
            address(underlyingPf)
        );

        vm.label(address(underlyingPf), "DAI_PRICEFEED");
        vm.label(address(yearnMock), "YEARN_MOCK");

        vm.label(address(pf), "YEARN_PRICE_FEED");
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [OYPF-1]: constructor sets correct values
    function test_OYPF_01_constructor_sets_correct_values() public {
        // LP2

        assertEq(pf.description(), "yearn DAI priceFeed", "Incorrect description");

        assertEq(address(pf.priceFeed()), address(underlyingPf), "Incorrect priceFeed");

        assertEq(address(pf.yVault()), address(yearnMock), "Incorrect yVault");

        assertEq(
            pf.decimalsDivider(),
            10 ** 18, // Decimals divider for DAI
            "Incorrect decimals"
        );

        assertTrue(pf.skipPriceCheck() == true, "Incorrect deepencds for address");

        assertEq(pf.lowerBound(), yearnMock.pricePerShare(), "Incorrect lower bound");

        assertEq(
            pf.upperBound(),
            (yearnMock.pricePerShare() * (PERCENTAGE_FACTOR + RANGE_WIDTH)) / PERCENTAGE_FACTOR,
            "Incorrect upper bound"
        );
    }

    /// @dev [OYPF-2]: constructor reverts for zero addresses
    function test_OYPF_02_constructor_reverts_for_zero_addresses() public {
        vm.expectRevert(ZeroAddressException.selector);

        new YearnPriceFeed(address(addressProvider), address(0), address(0));

        vm.expectRevert(ZeroAddressException.selector);
        new YearnPriceFeed(
            address(addressProvider),
            address(yearnMock),
            address(0)
        );
    }

    /// @dev [OYPF-4]: latestRoundData works correctly
    function test_OYPF_04_latestRoundData_works_correctly(uint8 add) public {
        uint256 pricePerShare = pf.lowerBound() + add;

        vm.assume(pricePerShare < pf.upperBound());

        vm.prank(CONFIGURATOR);
        yearnMock.setPricePerShare(pricePerShare);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            pf.latestRoundData();

        int256 expectedAnswer = int256((pricePerShare * uint256(1100)) / WAD);

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, expectedAnswer, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");
    }

    /// @dev [OYPF-5]: latestRoundData works correctly
    function test_OYPF_05_latestRoundData_reverts_or_bounds_for_out_of_bounds_prices() public {
        uint256 lowerBound = pf.lowerBound();
        uint256 upperBound = pf.upperBound();

        vm.prank(CONFIGURATOR);
        yearnMock.setPricePerShare(lowerBound - 1);

        vm.expectRevert(ValueOutOfRangeException.selector);
        pf.latestRoundData();

        vm.prank(CONFIGURATOR);
        yearnMock.setPricePerShare(upperBound + 1);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            pf.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 1122, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        vm.prank(CONFIGURATOR);
        yearnMock.setPricePerShare(lowerBound);
        underlyingPf.setPrice(0);

        vm.expectRevert(ZeroPriceException.selector);
        pf.latestRoundData();

        underlyingPf.setPrice(100);
        underlyingPf.setParams(80, block.timestamp, block.timestamp, 78);

        vm.expectRevert(ChainPriceStaleException.selector);
        pf.latestRoundData();

        underlyingPf.setParams(80, block.timestamp, 0, 80);
        vm.expectRevert(ChainPriceStaleException.selector);
        pf.latestRoundData();
    }

    /// @dev [OYPF-6]: setLimiter reverts if pricePerShare is outside new bounds
    function test_OYPF_06_setLimiter_reverts_on_pricePerShare_outside_bounds() public {
        yearnMock.setPricePerShare((15000 * WAD) / 10000);

        vm.expectRevert(IncorrectLimitsException.selector);
        pf.setLimiter(WAD);

        vm.expectRevert(IncorrectLimitsException.selector);
        pf.setLimiter((16000 * WAD) / 10000);
    }
}
