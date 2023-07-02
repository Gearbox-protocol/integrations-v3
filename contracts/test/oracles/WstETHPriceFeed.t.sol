// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {WstETHPriceFeed, RANGE_WIDTH} from "../../oracles/lido/WstETHPriceFeed.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/PercentageMath.sol";

// LIBRARIES

// TEST
import "../lib/constants.sol";

// MOCKS
import {WstETHV1Mock} from "../mocks/integrations/WstETHV1Mock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";

// SUITES
import {TokensTestSuite, Tokens} from "../suites/TokensTestSuite.sol";

// EXCEPTIONS

import {IPriceOracleV2Exceptions} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceOracleV2.sol";

/// @title WstETHFeedTest
/// @notice Designed for unit test purposes only
contract WstETHFeedTest is Test, ILPPriceFeedExceptions, IPriceOracleV2Exceptions {
    AddressProviderV3ACLMock public addressProvider;
    WstETHV1Mock public wstETHMock;

    PriceFeedMock public underlyingPf;

    WstETHPriceFeed public pf;

    TokensTestSuite tokenTestSuite;

    function setUp() public {
        addressProvider = new AddressProviderV3ACLMock();

        underlyingPf = new PriceFeedMock(1100, 8);

        underlyingPf.setParams(11, 1111, 1112, 11);

        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{value: 100 * WAD}();

        wstETHMock = new WstETHV1Mock(tokenTestSuite.addressOf(Tokens.STETH));

        vm.prank(CONFIGURATOR);
        wstETHMock.setStEthPerToken(2 * WAD);

        pf = new WstETHPriceFeed(
            address(addressProvider),
            address(wstETHMock),
            address(underlyingPf)
        );

        vm.label(address(underlyingPf), "stETH_PRICEFEED");
        vm.label(address(wstETHMock), "WstETH_MOCK");

        vm.label(address(pf), "WstETH_PRICE_FEED");
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [WSTPF-1]: constructor sets correct values
    function test_WSTPF_01_constructor_sets_correct_values() public {
        // LP2

        assertEq(pf.description(), "Wrapped stETH priceFeed", "Incorrect description");

        assertEq(address(pf.wstETH()), address(wstETHMock), "Incorrect priceFeed");

        assertEq(address(pf.priceFeed()), address(underlyingPf), "Incorrect priceFeed");

        assertEq(
            pf.decimalsDivider(),
            10 ** 18, // Decimals divider for stETH
            "Incorrect decimals"
        );

        assertTrue(pf.skipPriceCheck() == true, "Incorrect deepencds for address");

        assertEq(pf.lowerBound(), wstETHMock.stEthPerToken(), "Incorrect lower bound");

        assertEq(
            pf.upperBound(),
            (wstETHMock.stEthPerToken() * (PERCENTAGE_FACTOR + RANGE_WIDTH)) / PERCENTAGE_FACTOR,
            "Incorrect upper bound"
        );
    }

    /// @dev [WSTPF-2]: constructor reverts for zero addresses
    function test_WSTPF_02_constructor_reverts_for_zero_addresses() public {
        vm.expectRevert(ZeroAddressException.selector);

        new WstETHPriceFeed(address(addressProvider), address(0), address(0));

        vm.expectRevert(ZeroAddressException.selector);
        new WstETHPriceFeed(
            address(addressProvider),
            address(wstETHMock),
            address(0)
        );
    }

    /// @dev [WSTPF-4]: latestRoundData works correctly
    function test_WSTPF_04_latestRoundData_works_correctly(uint8 add) public {
        uint256 diff = pf.upperBound() - pf.lowerBound();
        uint256 stEthPerToken = pf.lowerBound() + (add * diff) / 256;

        vm.prank(CONFIGURATOR);
        wstETHMock.setStEthPerToken(stEthPerToken);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            pf.latestRoundData();

        int256 expectedAnswer = int256((stEthPerToken * uint256(1100)) / WAD);

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, expectedAnswer, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");
    }

    /// @dev [WSTPF-5]: latestRoundData works correctly
    function test_WSTPF_05_latestRoundData_reverts_or_bounds_for_out_of_bounds_prices() public {
        uint256 lowerBound = pf.lowerBound();
        uint256 upperBound = pf.upperBound();

        vm.prank(CONFIGURATOR);
        wstETHMock.setStEthPerToken(lowerBound - 1);

        vm.expectRevert(ValueOutOfRangeException.selector);
        pf.latestRoundData();

        vm.prank(CONFIGURATOR);
        wstETHMock.setStEthPerToken(upperBound + 1);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            pf.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 1122 * 2, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        vm.prank(CONFIGURATOR);
        wstETHMock.setStEthPerToken(lowerBound);
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

    /// @dev [WSTPF-6]: setLimiter reverts if stEthPerToken is outside new bounds
    function test_WSTPF_06_setLimiter_reverts_on_stEthPerToken_outside_bounds() public {
        wstETHMock.setStEthPerToken((15000 * WAD) / 10000);

        vm.expectRevert(IncorrectLimitsException.selector);
        pf.setLimiter(WAD);

        vm.expectRevert(IncorrectLimitsException.selector);
        pf.setLimiter((16000 * WAD) / 10000);
    }
}
