// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {ILPPriceFeedExceptions} from "@gearbox-protocol/core-v3/contracts/interfaces/ILPPriceFeed.sol";
import {CurveCryptoLPPriceFeed} from "../../oracles/curve/CurveCryptoLPPriceFeed.sol";

// LIBRARIES

// TEST
import "../lib/constants.sol";

// MOCKS
import {CurveV1Mock} from "../mocks/integrations/CurveV1Mock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v2/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {AddressProviderACLMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderACLMock.sol";

// SUITES
import {TokensTestSuite, Tokens} from "../suites/TokensTestSuite.sol";

// EXCEPTIONS
import {
    ZeroAddressException, NotImplementedException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IErrors.sol";

/// @title CurveLPPriceFeedTest
/// @notice Designed for unit test purposes only
contract CurveLPPriceFeedTest is DSTest, ILPPriceFeedExceptions {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    AddressProviderACLMock public addressProvider;
    CurveV1Mock public curveV1Mock;

    PriceFeedMock public pfm1;
    PriceFeedMock public pfm2;
    PriceFeedMock public pfm3;

    CurveCryptoLPPriceFeed public cc2feed;
    CurveCryptoLPPriceFeed public cc3feed;

    TokensTestSuite tokenTestSuite;

    function setUp() public {
        addressProvider = new AddressProviderACLMock();

        pfm1 = new PriceFeedMock(6400000000, 8);
        pfm2 = new PriceFeedMock(100000000, 8);
        pfm3 = new PriceFeedMock(6400000000, 8);

        pfm1.setParams(11, 1111, 1112, 11);
        pfm2.setParams(22, 2222, 2223, 22);
        pfm3.setParams(33, 3333, 3334, 33);

        address[] memory _coins;
        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{value: 100 * WAD}();

        curveV1Mock = new CurveV1Mock(_coins, _coins);
        curveV1Mock.set_virtual_price(WAD);

        cc2feed = new CurveCryptoLPPriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(pfm2),
            address(0),
            "LP2"
        );

        cc3feed = new CurveCryptoLPPriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(pfm2),
            address(pfm3),
            "LP3"
        );
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [OCCLP-1]: constructor sets correct values
    function test_OCCLP_01_constructor_sets_correct_values() public {
        // LP2

        assertEq(address(cc2feed.priceFeed1()), address(pfm1), "LP2: incorrect priceFeed1");

        assertEq(address(cc2feed.priceFeed2()), address(pfm2), "LP2: incorrect priceFeed2");

        assertEq(address(cc2feed.curvePool()), address(curveV1Mock), "LP2: incorrect curvePool");

        assertEq(cc2feed.description(), "LP2", "LP2: incorrect description");

        // LP3

        assertEq(address(cc3feed.priceFeed1()), address(pfm1), "LP3: incorrect priceFeed1");

        assertEq(address(cc3feed.priceFeed2()), address(pfm2), "LP3: incorrect priceFeed2");

        assertEq(address(cc3feed.priceFeed3()), address(pfm3), "LP3: incorrect priceFeed3");

        assertEq(address(cc3feed.curvePool()), address(curveV1Mock), "LP3: incorrect curvePool");

        assertEq(cc3feed.description(), "LP3", "LP3: incorrect description");

        // LP4

        assertEq(cc2feed.lowerBound(), WAD, "LP2: Incorrect lower bound");

        assertEq(cc3feed.lowerBound(), WAD, "LP3: Incorrect lower bound");
    }

    /// @dev [OCCLP-2]: constructor reverts for zero addresses
    function test_OCCLP_02_constructor_reverts_for_zero_addresses() public {
        evm.expectRevert(ZeroAddressException.selector);

        new CurveCryptoLPPriceFeed(
            address(addressProvider),
            address(0),
            address(pfm1),
            address(pfm2),
            address(0),
            "LP2"
        );

        evm.expectRevert(ZeroAddressException.selector);
        new CurveCryptoLPPriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(0),
            address(pfm2),
            address(0),
            "LP2"
        );

        evm.expectRevert(ZeroAddressException.selector);
        new CurveCryptoLPPriceFeed(
            address(addressProvider),
            address(curveV1Mock),
            address(pfm1),
            address(0),
            address(0),
            "LP2"
        );
    }

    /// @dev [OCCLP-3]: latestRoundData works correctly for 2 assets CurveCryptoLPPriceFeed

    function test_OCCLP_03_latestRoundData_works_correctly_for_2_assets_CurveLPPriceFeed() public {
        curveV1Mock.set_virtual_price((10050 * WAD) / 10000);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            cc2feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 1600000000 * 10050 / 10000 - 1, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        pfm2.setPrice(400000000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = cc2feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #2");
        assertEq(answer, 3200000000 * 10050 / 10000 - 1, "Incorrect answer #2");
        assertEq(startedAt, 1111, "Incorrect startedAt #2");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #2");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #2");

        curveV1Mock.set_virtual_price((10100 * WAD) / 10000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = cc2feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #2");
        assertEq(answer, 3200000000 * 10100 / 10000 - 1, "Incorrect answer #2");
        assertEq(startedAt, 1111, "Incorrect startedAt #2");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #2");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #2");
    }

    /// @dev [OCCLP-4]: latestRoundData works correctly for 3 assets CurveCryptoLPPriceFeed

    function test_OCCLP_04_latestRoundData_works_correctly_for_3_assets_CurveLPPriceFeed() public {
        curveV1Mock.set_virtual_price((10050 * WAD) / 10000);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            cc3feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 4800000000 * 10050 / 10000 - 1, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        pfm2.setPrice(800000000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = cc3feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #2");
        assertEq(answer, 9600000000 * 10050 / 10000 - 1, "Incorrect answer #2");
        assertEq(startedAt, 1111, "Incorrect startedAt #2");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #2");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #2");

        curveV1Mock.set_virtual_price((10100 * WAD) / 10000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = cc3feed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #3");
        assertEq(answer, 9600000000 * 10100 / 10000 - 1, "Incorrect answer #3");
        assertEq(startedAt, 1111, "Incorrect startedAt #3");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #3");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #3");
    }
}
