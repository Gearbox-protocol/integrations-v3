// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {RAY, WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/PercentageMath.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";

import "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {WrappedAToken} from "../../adapters/aave/WrappedAToken.sol";

import {AavePriceFeed, RANGE_WIDTH} from "../../oracles/aave/AavePriceFeed.sol";

import {ATokenMock} from "../mocks/integrations/aave/ATokenMock.sol";
import {LendingPoolMock} from "../mocks/integrations/aave/LendingPoolMock.sol";
import {TokensTestSuite, Tokens} from "../suites/TokensTestSuite.sol";

/// @title Aave V2 wrapped aToken price feed test
/// @notice [OAPF]: Unit tests for Aave V2 wrapped aToken price feed
contract AavePriceFeedTest is Test {
    TokensTestSuite tokensTestSuite;
    AddressProviderV3ACLMock addressProvider;

    address dai;
    ATokenMock aDai;
    WrappedAToken waDai;
    LendingPoolMock lendingPool;

    PriceFeedMock daiPriceFeed;
    AavePriceFeed public waDaiPriceFeed;

    int256 constant DAI_PRICE = 1.1e8;

    function setUp() public {
        tokensTestSuite = new TokensTestSuite();

        addressProvider = new AddressProviderV3ACLMock();

        dai = tokensTestSuite.addressOf(Tokens.DAI);
        lendingPool = new LendingPoolMock();
        // set yearly interest equal to the range width
        aDai = ATokenMock(lendingPool.addReserve(dai, RANGE_WIDTH * RAY / PERCENTAGE_FACTOR));
        tokensTestSuite.mint(Tokens.DAI, address(aDai), 1_000_000e18);
        waDai = new WrappedAToken(aDai);

        daiPriceFeed = new PriceFeedMock(DAI_PRICE, 8);
        daiPriceFeed.setParams(11, 1111, 1112, 11);
        waDaiPriceFeed = new AavePriceFeed(address(addressProvider), address(waDai), address(daiPriceFeed));

        vm.label(address(lendingPool), "LENDING_POOL_MOCK");
        vm.label(address(aDai), "aDAI");
        vm.label(address(waDai), "waDAI");
        vm.label(address(daiPriceFeed), "DAI_PRICE_FEED");
        vm.label(address(waDaiPriceFeed), "waDAI_PRICE_FEED");
    }

    /// @notice [OAPF-1]: Constructor reverts on zero address
    function test_OAPF_01_constructor_reverts_on_zero_address() public {
        vm.expectRevert(ZeroAddressException.selector);
        new AavePriceFeed(address(addressProvider), address(0), address(daiPriceFeed));

        vm.expectRevert(ZeroAddressException.selector);
        new AavePriceFeed(address(addressProvider), address(waDai), address(0));
    }

    /// @notice [OAPF-2]: Constructor sets correct values
    function test_OAPF_02_constructor_sets_correct_values() public {
        assertEq(waDaiPriceFeed.description(), "Wrapped Aave interest bearing DAI priceFeed", "Incorrect description");
        assertEq(address(waDaiPriceFeed.priceFeed()), address(daiPriceFeed), "Incorrect priceFeed");
        assertEq(address(waDaiPriceFeed.waToken()), address(waDai), "Incorrect waToken");
        assertEq(waDaiPriceFeed.decimalsDivider(), WAD, "Incorrect decimalsDivider");
        assertTrue(waDaiPriceFeed.skipPriceCheck() == true, "Incorrect skipPriceCheck");
        assertEq(waDaiPriceFeed.lowerBound(), waDai.exchangeRate(), "Incorrect lower bound");
        assertEq(
            waDaiPriceFeed.upperBound(),
            waDai.exchangeRate() * (PERCENTAGE_FACTOR + RANGE_WIDTH) / PERCENTAGE_FACTOR,
            "Incorrect upper bound"
        );
    }

    /// @notice [OAPF-3]: `latestRoundData` works correctly
    function test_OAPF_03_latestRoundData_works_correctly(uint256 timedelta) public {
        vm.assume(timedelta < 365 days);
        vm.warp(block.timestamp + timedelta);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            waDaiPriceFeed.latestRoundData();

        int256 expectedAnswer = int256(uint256(DAI_PRICE) * waDai.exchangeRate() / WAD);

        assertEq(roundId, 11, "Incorrect roundId");
        assertEq(answer, expectedAnswer, "Incorrect answer");
        assertEq(startedAt, 1111, "Incorrect startedAt");
        assertEq(updatedAt, 1112, "Incorrect updatedAt");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound");
    }

    /// @notice [OAPF-4]: `latestRoundData` handles out-of-bounds exchange rate correctly
    function test_OAPF_04_latestRoundData_handles_out_of_bounds_exchangeRate_correctly() public {
        // interest accrued after 2 years is greater than range width, so price feed must return upper-bounded value
        vm.warp(block.timestamp + 2 * 365 days);

        (, int256 answer,,,) = waDaiPriceFeed.latestRoundData();
        int256 expectedAnswer = int256(uint256(DAI_PRICE) * waDaiPriceFeed.upperBound() / WAD);
        assertEq(answer, expectedAnswer, "Answer not upper-bounded");

        // not testing for exchangeRate below lower bound because it simply can't decrease over time,
        // based on Aave and waToken contracts
    }

    /// @notice [OAPF-5]: `setLimiter` reverts on out-of-bounds exchange rate
    function test_OAPF_05_setLimiter_reverts_on_out_of_bounds_exchangeRate() public {
        uint256 exchangeRate = waDai.exchangeRate();

        vm.expectRevert(ILPPriceFeedExceptions.IncorrectLimitsException.selector);
        waDaiPriceFeed.setLimiter(exchangeRate + 1);

        vm.expectRevert(ILPPriceFeedExceptions.IncorrectLimitsException.selector);
        waDaiPriceFeed.setLimiter(exchangeRate * PERCENTAGE_FACTOR / (PERCENTAGE_FACTOR + RANGE_WIDTH));
    }
}
