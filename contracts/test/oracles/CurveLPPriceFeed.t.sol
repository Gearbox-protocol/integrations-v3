// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {ILPPriceFeedExceptions} from "@gearbox-protocol/core-v2/contracts/interfaces/ILPPriceFeed.sol";
import {CurveLP2PriceFeed} from "../../oracles/curve/CurveLP2PriceFeed.sol";
import {CurveLP3PriceFeed} from "../../oracles/curve/CurveLP3PriceFeed.sol";
import {CurveLP4PriceFeed} from "../../oracles/curve/CurveLP4PriceFeed.sol";

// LIBRARIES

// TEST
import "../lib/constants.sol";

// MOCKS
import {CurveV1Mock} from "../mocks/integrations/CurveV1Mock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v2/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {AddressProviderACLMock} from "@gearbox-protocol/core-v2/contracts/test/mocks/core/AddressProviderACLMock.sol";

// SUITES
import {TokensTestSuite, Tokens} from "../suites/TokensTestSuite.sol";

// EXCEPTIONS
import {
    ZeroAddressException, NotImplementedException
} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

/// @title CurveLPPriceFeedTest
/// @notice Designed for unit test purposes only
contract CurveLPPriceFeedTest is DSTest, ILPPriceFeedExceptions {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    AddressProviderACLMock public addressProvider;
    CurveV1Mock public curveV1Mock;

    PriceFeedMock public pfm1;
    PriceFeedMock public pfm2;
    PriceFeedMock public pfm3;
    PriceFeedMock public pfm4;

    CurveLP2PriceFeed public c2feed;
    CurveLP3PriceFeed public c3feed;
    CurveLP4PriceFeed public c4feed;

    TokensTestSuite tokenTestSuite;

    function setUp() public {
        addressProvider = new AddressProviderACLMock();

        pfm1 = new PriceFeedMock(1100, 8);
        pfm2 = new PriceFeedMock(2200, 8);
        pfm3 = new PriceFeedMock(3300, 8);
        pfm4 = new PriceFeedMock(4400, 8);

        pfm1.setParams(11, 1111, 1112, 11);
        pfm2.setParams(22, 2222, 2223, 22);
        pfm3.setParams(33, 3333, 3334, 33);
        pfm4.setParams(44, 4444, 4445, 44);

        address[] memory _coins;
        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{value: 100 * WAD}();

        curveV1Mock = new CurveV1Mock(_coins, _coins);
        curveV1Mock.set_virtual_price(WAD);

        c2feed = new CurveLP2PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(pfm2),
            "LP2"
        );

        c3feed = new CurveLP3PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(pfm2),
            address(pfm3),
            "LP3"
        );

        c4feed = new CurveLP4PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(pfm2),
            address(pfm3),
            address(pfm4),
            "LP4"
        );
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [OCLP-1]: constructor sets correct values
    function test_OCLP_01_constructor_sets_correct_values() public {
        // LP2

        assertEq(address(c2feed.priceFeed1()), address(pfm1), "LP2: incorrect priceFeed1");

        assertEq(address(c2feed.priceFeed2()), address(pfm2), "LP2: incorrect priceFeed2");

        assertEq(address(c2feed.curvePool()), address(curveV1Mock), "LP2: incorrect curvePool");

        assertEq(c2feed.description(), "LP2", "LP2: incorrect description");

        // LP3

        assertEq(address(c3feed.priceFeed1()), address(pfm1), "LP3: incorrect priceFeed1");

        assertEq(address(c3feed.priceFeed2()), address(pfm2), "LP3: incorrect priceFeed2");

        assertEq(address(c3feed.priceFeed3()), address(pfm3), "LP3: incorrect priceFeed3");

        assertEq(address(c3feed.curvePool()), address(curveV1Mock), "LP3: incorrect curvePool");

        assertEq(c3feed.description(), "LP3", "LP3: incorrect description");

        // LP4

        assertEq(address(c4feed.priceFeed1()), address(pfm1), "LP4: incorrect priceFeed1");

        assertEq(address(c4feed.priceFeed2()), address(pfm2), "LP4: incorrect priceFeed2");

        assertEq(address(c4feed.priceFeed3()), address(pfm3), "LP4: incorrect priceFeed3");

        assertEq(address(c4feed.priceFeed4()), address(pfm4), "LP4: incorrect priceFeed4");

        assertEq(address(c4feed.curvePool()), address(curveV1Mock), "LP4: incorrect curvePool");

        assertEq(c4feed.description(), "LP4", "LP4: incorrect description");

        assertEq(c2feed.lowerBound(), WAD, "LP2: Incorrect lower bound");

        assertEq(c3feed.lowerBound(), WAD, "LP3: Incorrect lower bound");

        assertEq(c4feed.lowerBound(), WAD, "LP4: Incorrect lower bound");
    }

    /// @dev [OCLP-2]: constructor reverts for zero addresses
    function test_OCLP_02_constructor_reverts_for_zero_addresses() public {
        evm.expectRevert(ZeroAddressException.selector);

        new CurveLP2PriceFeed(
            address(addressProvider),
            address(0),
            address(pfm1),
            address(pfm2),
            "LP2"
        );

        evm.expectRevert(ZeroAddressException.selector);
        new CurveLP2PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(0),
            address(pfm2),
            "LP2"
        );

        evm.expectRevert(ZeroAddressException.selector);
        new CurveLP2PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(0),
            "LP2"
        );

        // LP3

        evm.expectRevert(ZeroAddressException.selector);
        c3feed = new CurveLP3PriceFeed(
            address(addressProvider),
            address(0),
            address(pfm1),
            address(pfm2),
            address(pfm3),
            "LP3"
        );

        evm.expectRevert(ZeroAddressException.selector);
        c3feed = new CurveLP3PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(0),
            address(pfm2),
            address(pfm3),
            "LP3"
        );

        evm.expectRevert(ZeroAddressException.selector);
        c3feed = new CurveLP3PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(0),
            address(pfm3),
            "LP3"
        );

        evm.expectRevert(ZeroAddressException.selector);
        c3feed = new CurveLP3PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(pfm2),
            address(0),
            "LP3"
        );

        // LP4
        evm.expectRevert(ZeroAddressException.selector);
        c4feed = new CurveLP4PriceFeed(
            address(addressProvider),
            address(0),
            address(pfm1),
            address(pfm2),
            address(pfm3),
            address(pfm4),
            "LP4"
        );

        evm.expectRevert(ZeroAddressException.selector);
        c4feed = new CurveLP4PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(0),
            address(pfm2),
            address(pfm3),
            address(pfm4),
            "LP4"
        );

        evm.expectRevert(ZeroAddressException.selector);
        c4feed = new CurveLP4PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(0),
            address(pfm3),
            address(pfm4),
            "LP4"
        );

        evm.expectRevert(ZeroAddressException.selector);
        c4feed = new CurveLP4PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(pfm2),
            address(0),
            address(pfm4),
            "LP4"
        );

        evm.expectRevert(ZeroAddressException.selector);
        c4feed = new CurveLP4PriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(pfm2),
            address(pfm3),
            address(0),
            "LP4"
        );
    }

    /// @dev [OCLP-3]: constructor reverts at getRoundData call
    function test_OCLP_03_constructor_reverts_at_getRoundData_call() public {
        evm.expectRevert(NotImplementedException.selector);
        c2feed.getRoundData(1);

        evm.expectRevert(NotImplementedException.selector);
        c3feed.getRoundData(1);

        evm.expectRevert(NotImplementedException.selector);
        c4feed.getRoundData(1);
    }

    /// @dev [OCLP-4]: latestRoundData works correctly for 2 assets CurveLPPriceFeed

    function test_OCLP_04_latestRoundData_works_correctly_for_2_assets_CurveLPPriceFeed() public {
        curveV1Mock.set_virtual_price((10050 * WAD) / 10000);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            c2feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 1105, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        pfm2.setPrice(1000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = c2feed.latestRoundData();

        assertEq(roundId, 22, "Incorrect round Id #2");
        assertEq(answer, 1005, "Incorrect answer #2");
        assertEq(startedAt, 2222, "Incorrect startedAt #2");
        assertEq(updatedAt, 2223, "Incorrect updatedAt #2");
        assertEq(answeredInRound, 22, "Incorrect answeredInRound #2");

        curveV1Mock.set_virtual_price((10100 * WAD) / 10000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = c2feed.latestRoundData();

        assertEq(roundId, 22, "Incorrect round Id #3");
        assertEq(answer, 1010, "Incorrect answer #3");
        assertEq(startedAt, 2222, "Incorrect startedAt #3");
        assertEq(updatedAt, 2223, "Incorrect updatedAt #3");
        assertEq(answeredInRound, 22, "Incorrect answeredInRound #3");
    }

    /// @dev [OCLP-5]: latestRoundData works correctly for 3 assets CurveLPPriceFeed

    function test_OCLP_05_latestRoundData_works_correctly_for_3_assets_CurveLPPriceFeed() public {
        curveV1Mock.set_virtual_price((10050 * WAD) / 10000);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            c3feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 1105, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        pfm3.setPrice(1000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = c3feed.latestRoundData();

        assertEq(roundId, 33, "Incorrect round Id #2");
        assertEq(answer, 1005, "Incorrect answer #2");
        assertEq(startedAt, 3333, "Incorrect startedAt #2");
        assertEq(updatedAt, 3334, "Incorrect updatedAt #2");
        assertEq(answeredInRound, 33, "Incorrect answeredInRound #2");

        curveV1Mock.set_virtual_price((10100 * WAD) / 10000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = c3feed.latestRoundData();

        assertEq(roundId, 33, "Incorrect round Id #3");
        assertEq(answer, 1010, "Incorrect answer #3");
        assertEq(startedAt, 3333, "Incorrect startedAt #3");
        assertEq(updatedAt, 3334, "Incorrect updatedAt #3");
        assertEq(answeredInRound, 33, "Incorrect answeredInRound #3");
    }

    /// @dev [OCLP-6]: latestRoundData works correctly for 4 assets CurveLPPriceFeed

    function test_OCLP_06_latestRoundData_works_correctly_for_4_assets_CurveLPPriceFeed() public {
        curveV1Mock.set_virtual_price((10050 * WAD) / 10000);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            c4feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 1105, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        pfm4.setPrice(1000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = c4feed.latestRoundData();

        assertEq(roundId, 44, "Incorrect round Id #2");
        assertEq(answer, 1005, "Incorrect answer #2");
        assertEq(startedAt, 4444, "Incorrect startedAt #2");
        assertEq(updatedAt, 4445, "Incorrect updatedAt #2");
        assertEq(answeredInRound, 44, "Incorrect answeredInRound #2");

        curveV1Mock.set_virtual_price((10100 * WAD) / 10000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = c4feed.latestRoundData();

        assertEq(roundId, 44, "Incorrect round Id #3");
        assertEq(answer, 1010, "Incorrect answer #3");
        assertEq(startedAt, 4444, "Incorrect startedAt #3");
        assertEq(updatedAt, 4445, "Incorrect updatedAt #3");
        assertEq(answeredInRound, 44, "Incorrect answeredInRound #3");
    }

    /// @dev [OCLP-7]: latestRoundData reverts for out of bounds prices

    function test_OCLP_07_latestRoundData_reverts_for_out_of_bounds_prices() public {
        curveV1Mock.set_virtual_price((9000 * WAD) / 10000);

        evm.expectRevert(ValueOutOfRangeException.selector);
        c2feed.latestRoundData();

        evm.expectRevert(ValueOutOfRangeException.selector);
        c3feed.latestRoundData();

        evm.expectRevert(ValueOutOfRangeException.selector);
        c4feed.latestRoundData();

        curveV1Mock.set_virtual_price((15000 * WAD) / 10000);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            c2feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 1122, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        (roundId, answer, startedAt, updatedAt, answeredInRound) = c3feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 1122, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        (roundId, answer, startedAt, updatedAt, answeredInRound) = c4feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 1122, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");
    }

    /// @dev [OCLP-8]: setLimiter reverts if virtual price is outside new bounds
    function test_OCLP_08_setLimiter_reverts_on_virtual_price_outside_bounds() public {
        curveV1Mock.set_virtual_price((15000 * WAD) / 10000);

        evm.expectRevert(IncorrectLimitsException.selector);
        c2feed.setLimiter(WAD);

        evm.expectRevert(IncorrectLimitsException.selector);
        c2feed.setLimiter((16000 * WAD) / 10000);
    }
}
