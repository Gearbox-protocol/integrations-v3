// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/PercentageMath.sol";
import {AddressProviderV3ACLMock} from
    "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceFeedMock.sol";

import "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {CompoundPriceFeed, RANGE_WIDTH} from "../../oracles/compound/CompoundPriceFeed.sol";

import {CErc20Mock} from "../mocks/integrations/compound/CErc20Mock.sol";
import {TokensTestSuite, Tokens} from "../suites/TokensTestSuite.sol";

/// @title Compound V2 cToken price feed test
/// @notice [OCPF]: Unit tests for Compound V2 cToken price feed
contract CompoundPriceFeedTest is Test {
    TokensTestSuite tokensTestSuite;
    AddressProviderV3ACLMock addressProvider;

    address dai;
    CErc20Mock cdai;

    PriceFeedMock daiPriceFeed;
    CompoundPriceFeed public cdaiPriceFeed;

    int256 constant DAI_PRICE = 1.1e8;

    function setUp() public {
        tokensTestSuite = new TokensTestSuite();

        addressProvider = new AddressProviderV3ACLMock();

        dai = tokensTestSuite.addressOf(Tokens.DAI);
        // set yearly interest equal to the range width
        cdai = new CErc20Mock(dai, 0.02 ether, WAD * RANGE_WIDTH / PERCENTAGE_FACTOR);
        tokensTestSuite.mint(dai, address(cdai), 100_000e18);

        daiPriceFeed = new PriceFeedMock(DAI_PRICE, 8);
        daiPriceFeed.setParams(11, 1111, 1112, 11);
        cdaiPriceFeed = new CompoundPriceFeed(address(addressProvider), address(cdai), address(daiPriceFeed));

        vm.label(address(cdai), "cDAI");
        vm.label(address(daiPriceFeed), "DAI_PRICE_FEED");
        vm.label(address(cdaiPriceFeed), "cDAI_PRICE_FEED");
    }

    /// @notice [OCPF-1]: Constructor reverts on zero address
    function test_OCPF_01_constructor_reverts_on_zero_address() public {
        vm.expectRevert(ZeroAddressException.selector);
        new CompoundPriceFeed(address(addressProvider), address(0), address(daiPriceFeed));

        vm.expectRevert(ZeroAddressException.selector);
        new CompoundPriceFeed(address(addressProvider), address(cdai), address(0));
    }

    /// @notice [OCPF-2]: Constructor sets correct values
    function test_OCPF_02_constructor_sets_correct_values() public {
        assertEq(cdaiPriceFeed.description(), "Compound DAI priceFeed", "Incorrect description");
        assertEq(address(cdaiPriceFeed.priceFeed()), address(daiPriceFeed), "Incorrect priceFeed");
        assertEq(address(cdaiPriceFeed.cToken()), address(cdai), "Incorrect cToken");
        assertEq(cdaiPriceFeed.decimalsDivider(), WAD, "Incorrect decimalsDivider");
        assertTrue(cdaiPriceFeed.skipPriceCheck() == true, "Incorrect skipPriceCheck");
        assertEq(cdaiPriceFeed.lowerBound(), cdai.exchangeRateCurrent(), "Incorrect lower bound");
        assertEq(
            cdaiPriceFeed.upperBound(),
            cdai.exchangeRateCurrent() * (PERCENTAGE_FACTOR + RANGE_WIDTH) / PERCENTAGE_FACTOR,
            "Incorrect upper bound"
        );
    }

    /// @notice [OCPF-3]: `latestRoundData` works correctly
    function test_OCPF_03_latestRoundData_works_correctly(uint256 timedelta) public {
        vm.assume(timedelta < 365 days);
        vm.warp(block.timestamp + timedelta);
        cdai.accrueInterest();

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            cdaiPriceFeed.latestRoundData();

        int256 expectedAnswer = int256(uint256(DAI_PRICE) * cdai.exchangeRateCurrent() / WAD);

        assertEq(roundId, 11, "Incorrect roundId");
        assertEq(answer, expectedAnswer, "Incorrect answer");
        assertEq(startedAt, 1111, "Incorrect startedAt");
        assertEq(updatedAt, 1112, "Incorrect updatedAt");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound");
    }

    /// @notice [OCPF-4]: `latestRoundData` handles out-of-bounds exchange rate correctly
    function test_OCPF_04_latestRoundData_handles_out_of_bounds_exchangeRate_correctly() public {
        // interest accrued after 2 years is greater than range width, so price feed must return upper-bounded value
        vm.warp(block.timestamp + 2 * 365 days);
        cdai.accrueInterest();

        (, int256 answer,,,) = cdaiPriceFeed.latestRoundData();
        int256 expectedAnswer = int256(uint256(DAI_PRICE) * cdaiPriceFeed.upperBound() / WAD);
        assertEq(answer, expectedAnswer, "Answer not upper-bounded");

        // not testing for exchangeRate below lower bound because it simply can't decrease over time,
        // based on Compound contracts
    }

    /// @notice [OCPF-5]: `setLimiter` reverts on out-of-bounds exchange rate
    function test_OCPF_05_setLimiter_reverts_on_out_of_bounds_exchangeRate() public {
        uint256 exchangeRate = cdai.exchangeRateStored();

        vm.expectRevert(ILPPriceFeedExceptions.IncorrectLimitsException.selector);
        cdaiPriceFeed.setLimiter(exchangeRate + 1);

        vm.expectRevert(ILPPriceFeedExceptions.IncorrectLimitsException.selector);
        cdaiPriceFeed.setLimiter(exchangeRate * PERCENTAGE_FACTOR / (PERCENTAGE_FACTOR + RANGE_WIDTH));
    }
}
