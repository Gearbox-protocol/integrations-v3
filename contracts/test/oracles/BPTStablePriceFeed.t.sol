// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {ILPPriceFeedExceptions} from "@gearbox-protocol/core-v2/contracts/interfaces/ILPPriceFeed.sol";
import {
    IBalancerV2Vault,
    PoolSpecialization,
    SingleSwap,
    BatchSwapStep,
    FundManagement,
    SwapKind,
    JoinPoolRequest,
    ExitPoolRequest
} from "../../integrations/balancer/IBalancerV2Vault.sol";
import {BPTStablePriceFeed} from "../../oracles/balancer/BPTStablePriceFeed.sol";

// LIBRARIES

// TEST
import "../lib/constants.sol";

// MOCKS

import {BalancerVaultMock} from "../mocks/integrations/BalancerVaultMock.sol";
import {BPTStableMock} from "../mocks/integrations/BPTStableMock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v2/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {AddressProviderACLMock} from "@gearbox-protocol/core-v2/contracts/test/mocks/core/AddressProviderACLMock.sol";

// SUITES
import {TokensTestSuite, Tokens} from "../suites/TokensTestSuite.sol";

// EXCEPTIONS
import {
    ZeroAddressException,
    NotImplementedException,
    IncorrectPriceFeedException
} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

/// @title BPTStablePriceFeedTest
/// @notice Designed for unit test purposes only
contract BPTStablePriceFeedTest is DSTest, ILPPriceFeedExceptions {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    bytes32 public constant POOL_ID = bytes32(uint256(1));

    AddressProviderACLMock public addressProvider;

    BalancerVaultMock public balancerMock;
    BPTStableMock public bptMock;

    PriceFeedMock public pfm1;
    PriceFeedMock public pfm2;
    PriceFeedMock public pfm3;
    PriceFeedMock public pfm4;

    BPTStablePriceFeed public bptPriceFeed;

    TokensTestSuite tokenTestSuite;

    function setUp() public {
        addressProvider = new AddressProviderACLMock();

        pfm1 = new PriceFeedMock(99000000, 8);
        pfm2 = new PriceFeedMock(98000000, 8);
        pfm3 = new PriceFeedMock(100000000, 8);
        pfm4 = new PriceFeedMock(101000000, 8);

        pfm1.setParams(11, 1111, 1112, 11);
        pfm2.setParams(22, 2222, 2223, 22);
        pfm3.setParams(33, 3333, 3334, 33);
        pfm4.setParams(44, 4444, 4445, 44);

        address[] memory _coins = new address[](4);
        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{value: 100 * WAD}();

        _coins[0] = tokenTestSuite.addressOf(Tokens.DAI);
        _coins[1] = tokenTestSuite.addressOf(Tokens.USDT);
        _coins[2] = tokenTestSuite.addressOf(Tokens.USDC);
        _coins[3] = tokenTestSuite.addressOf(Tokens.cUSDC);

        balancerMock = new BalancerVaultMock();

        balancerMock.addStablePool(POOL_ID, _coins, 50);

        balancerMock.mintBPT(POOL_ID, USER, 1_000_000 * 10 ** 18);

        (address bptMockAddr,) = balancerMock.getPool(POOL_ID);

        bptMock = BPTStableMock(bptMockAddr);

        address[] memory priceFeeds = new address[](4);
        priceFeeds[0] = address(pfm1);
        priceFeeds[1] = address(pfm2);
        priceFeeds[2] = address(pfm3);
        priceFeeds[3] = address(pfm4);

        bptPriceFeed = new BPTStablePriceFeed(
            address(addressProvider),
            address(bptMock),
            4,
            priceFeeds
        );
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [OBSLP-1]: constructor sets correct values
    function test_OBSLP_01_constructor_sets_correct_values() public {
        assertEq(address(bptPriceFeed.priceFeed0()), address(pfm1), "Incorrect price feed 0");

        assertEq(address(bptPriceFeed.priceFeed1()), address(pfm2), "Incorrect price feed 1");

        assertEq(address(bptPriceFeed.priceFeed2()), address(pfm3), "Incorrect price feed 2");

        assertEq(address(bptPriceFeed.priceFeed3()), address(pfm4), "Incorrect price feed 3");

        assertEq(address(bptPriceFeed.priceFeed4()), address(0), "Incorrect price feed 4");

        assertEq(bptPriceFeed.numAssets(), 4, "Incorrect number of assets");

        assertEq(address(bptPriceFeed.balancerPool()), address(bptMock), "Incorrect balancer pool address");

        assertEq(bptPriceFeed.lowerBound(), WAD, "Incorrect lower bound");
    }

    function test_OBSLP_02_constructor_reverts_for_zero_addresses() public {
        address[] memory priceFeeds = new address[](4);
        priceFeeds[0] = address(pfm1);
        priceFeeds[1] = address(pfm2);
        priceFeeds[2] = address(pfm3);
        priceFeeds[3] = address(pfm4);

        evm.expectRevert(ZeroAddressException.selector);
        new BPTStablePriceFeed(
            address(addressProvider),
            address(0),
            4,
            priceFeeds
        );

        priceFeeds[1] = address(0);

        evm.expectRevert(ZeroAddressException.selector);
        new BPTStablePriceFeed(
            address(addressProvider),
            address(bptMock),
            4,
            priceFeeds
        );

        priceFeeds = new address[](5);
        evm.expectRevert(IncorrectPriceFeedException.selector);
        new BPTStablePriceFeed(
            address(addressProvider),
            address(bptMock),
            4,
            priceFeeds
        );
    }

    function test_OBSLP_03_latestRoundData_works_correctly() public {
        bptMock.setRate((10050 * WAD) / 10000);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            bptPriceFeed.latestRoundData();

        assertEq(roundId, 22, "Incorrect round Id #1");
        assertEq(answer, 98490000, "Incorrect answer #1");
        assertEq(startedAt, 2222, "Incorrect startedAt #1");
        assertEq(updatedAt, 2223, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 22, "Incorrect answeredInRound #1");

        pfm2.setPrice(100000000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = bptPriceFeed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 99495000, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        bptMock.setRate((10100 * WAD) / 10000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = bptPriceFeed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 99990000, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        bptMock.setRate((13000 * WAD) / 10000);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = bptPriceFeed.latestRoundData();

        assertEq(roundId, 11, "Incorrect round Id #1");
        assertEq(answer, 100980000, "Incorrect answer #1");
        assertEq(startedAt, 1111, "Incorrect startedAt #1");
        assertEq(updatedAt, 1112, "Incorrect updatedAt #1");
        assertEq(answeredInRound, 11, "Incorrect answeredInRound #1");

        bptMock.setRate((9000 * WAD) / 10000);

        evm.expectRevert(ValueOutOfRangeException.selector);
        bptPriceFeed.latestRoundData();
    }

    function test_OBSLP_05_setLimiter_reverts_on_value_out_of_new_bounds() external {
        bptMock.setRate((15000 * WAD) / 10000);

        evm.expectRevert(IncorrectLimitsException.selector);
        bptPriceFeed.setLimiter(WAD);

        evm.expectRevert(IncorrectLimitsException.selector);
        bptPriceFeed.setLimiter((16000 * WAD) / 10000);
    }
}
