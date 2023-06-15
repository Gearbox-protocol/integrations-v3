// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {ILPPriceFeedExceptions} from "@gearbox-protocol/core-v3/contracts/interfaces/ILPPriceFeed.sol";
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
import {BPTWeightedPriceFeed} from "../../oracles/balancer/BPTWeightedPriceFeed.sol";

// LIBRARIES

// TEST
import "../lib/constants.sol";

// MOCKS

import {BalancerVaultMock} from "../mocks/integrations/BalancerVaultMock.sol";
import {PriceFeedMock} from "@gearbox-protocol/core-v2/contracts/test/mocks/oracles/PriceFeedMock.sol";
import {AddressProviderACLMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderACLMock.sol";

// SUITES
import {TokensTestSuite, Tokens} from "../suites/TokensTestSuite.sol";

// EXCEPTIONS
import {
    ZeroAddressException, NotImplementedException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IErrors.sol";

/// @title BPTWeightedPriceFeedTest
/// @notice Designed for unit test purposes only
contract BPTWeightedPriceFeedTest is DSTest, ILPPriceFeedExceptions {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    bytes32 public constant POOL_ID = bytes32(uint256(1));

    AddressProviderACLMock public addressProvider;

    BalancerVaultMock public balancerMock;
    address public bptMock;

    PriceFeedMock public pfm1;
    PriceFeedMock public pfm2;
    PriceFeedMock public pfm3;
    PriceFeedMock public pfm4;
    PriceFeedMock public pfm5;
    PriceFeedMock public pfm6;
    PriceFeedMock public pfm7;
    PriceFeedMock public pfm8;

    BPTWeightedPriceFeed public bptPriceFeed;

    TokensTestSuite tokenTestSuite;

    function setUp() public {
        addressProvider = new AddressProviderACLMock();

        pfm1 = new PriceFeedMock(100000000000, 8);
        pfm2 = new PriceFeedMock(100000000, 8);
        pfm3 = new PriceFeedMock(100000000, 8);
        pfm4 = new PriceFeedMock(100000000, 8);

        pfm1.setParams(11, 1111, 1112, 11);
        pfm2.setParams(22, 2222, 2223, 22);
        pfm3.setParams(33, 3333, 3334, 33);
        pfm4.setParams(44, 4444, 4445, 44);

        address[] memory _coins = new address[](4);
        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{value: 100 * WAD}();

        _coins[0] = tokenTestSuite.addressOf(Tokens.WETH);
        _coins[1] = tokenTestSuite.addressOf(Tokens.DAI);
        _coins[2] = tokenTestSuite.addressOf(Tokens.USDT);
        _coins[3] = tokenTestSuite.addressOf(Tokens.USDC);

        balancerMock = new BalancerVaultMock();

        uint256[] memory weights = new uint256[](4);
        weights[0] = 40 * 10 ** 16;
        weights[1] = 20 * 10 ** 16;
        weights[2] = 30 * 10 ** 16;
        weights[3] = 10 * 10 ** 16;

        balancerMock.addPool(POOL_ID, _coins, weights, PoolSpecialization.GENERAL, 50);

        balancerMock.mintBPT(POOL_ID, USER, 1_000_000 * 10 ** 18);

        (bptMock,) = balancerMock.getPool(POOL_ID);

        uint256[] memory balances = new uint256[](4);

        balances[0] = 4000 * 10 ** 18;
        balances[1] = 2_000_000 * 10 ** 18;
        balances[2] = 3_000_000 * 10 ** 18;
        balances[3] = 1_000_000 * 10 ** 6;

        balancerMock.setAssetBalances(POOL_ID, balances);

        address[] memory priceFeeds = new address[](4);
        priceFeeds[0] = address(pfm1);
        priceFeeds[1] = address(pfm2);
        priceFeeds[2] = address(pfm3);
        priceFeeds[3] = address(pfm4);

        bptPriceFeed = new BPTWeightedPriceFeed(
            address(addressProvider),
            address(balancerMock),
            bptMock,
            priceFeeds
        );
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [OBWLP-1]: constructor sets correct values
    function test_OBWLP_01_constructor_sets_correct_values() public {
        assertEq(address(bptPriceFeed.priceFeed0()), address(pfm4), "Incorrect price feed 0");

        assertEq(address(bptPriceFeed.priceFeed1()), address(pfm2), "Incorrect price feed 1");

        assertEq(address(bptPriceFeed.priceFeed2()), address(pfm3), "Incorrect price feed 2");

        assertEq(address(bptPriceFeed.priceFeed3()), address(pfm1), "Incorrect price feed 3");

        assertEq(address(bptPriceFeed.priceFeed4()), address(0), "Incorrect price feed 4");

        assertEq(address(bptPriceFeed.priceFeed5()), address(0), "Incorrect price feed 5");

        assertEq(address(bptPriceFeed.priceFeed6()), address(0), "Incorrect price feed 6");

        assertEq(address(bptPriceFeed.priceFeed7()), address(0), "Incorrect price feed 7");

        assertEq(address(bptPriceFeed.asset0()), tokenTestSuite.addressOf(Tokens.USDC), "Incorrect asset 0");

        assertEq(address(bptPriceFeed.asset1()), tokenTestSuite.addressOf(Tokens.DAI), "Incorrect asset 1");

        assertEq(address(bptPriceFeed.asset2()), tokenTestSuite.addressOf(Tokens.USDT), "Incorrect asset 2");

        assertEq(address(bptPriceFeed.asset3()), tokenTestSuite.addressOf(Tokens.WETH), "Incorrect asset 3");

        assertEq(address(bptPriceFeed.asset4()), address(0), "Incorrect asset 4");

        assertEq(address(bptPriceFeed.asset5()), address(0), "Incorrect asset 5");

        assertEq(address(bptPriceFeed.asset6()), address(0), "Incorrect asset 6");

        assertEq(address(bptPriceFeed.asset7()), address(0), "Incorrect asset 7");

        assertEq(bptPriceFeed.normalizedWeight0(), 10 * 10 ** 16, "Incorrect weight 0");

        assertEq(bptPriceFeed.normalizedWeight1(), 20 * 10 ** 16, "Incorrect weight 1");

        assertEq(bptPriceFeed.normalizedWeight2(), 30 * 10 ** 16, "Incorrect weight 2");

        assertEq(bptPriceFeed.normalizedWeight3(), 40 * 10 ** 16, "Incorrect weight 3");

        assertEq(bptPriceFeed.normalizedWeight4(), 0, "Incorrect weight 4");

        assertEq(bptPriceFeed.normalizedWeight5(), 0, "Incorrect weight 5");

        assertEq(bptPriceFeed.normalizedWeight6(), 0, "Incorrect weight 6");

        assertEq(bptPriceFeed.normalizedWeight7(), 0, "Incorrect weight 7");

        assertEq(address(bptPriceFeed.balancerPool()), bptMock, "Incorrect balancer pool");

        assertEq(address(bptPriceFeed.balancerVault()), address(balancerMock), "Incorrect balancer vault");

        assertEq(bptPriceFeed.poolId(), POOL_ID, "Incorrect pool ID");

        assertEq(bptPriceFeed.numAssets(), 4, "Incorrect number of assets");
    }

    /// @dev [OBWLP-2]: constructor reverts for zero addresses
    function test_OBWLP_02_constructor_reverts_for_zero_addresses() public {
        address[] memory priceFeeds = new address[](4);
        priceFeeds[0] = address(pfm1);
        priceFeeds[1] = address(pfm2);
        priceFeeds[2] = address(pfm3);
        priceFeeds[3] = address(pfm4);

        evm.expectRevert(ZeroAddressException.selector);
        new BPTWeightedPriceFeed(
            address(addressProvider),
            address(0),
            address(0),
            priceFeeds
        );

        evm.expectRevert(ZeroAddressException.selector);
        new BPTWeightedPriceFeed(
            address(addressProvider),
            address(balancerMock),
            address(0),
            priceFeeds
        );

        priceFeeds[0] = address(0);

        evm.expectRevert(ZeroAddressException.selector);
        new BPTWeightedPriceFeed(
            address(addressProvider),
            address(balancerMock),
            bptMock,
            priceFeeds
        );
    }

    function test_OBWLP_03_latestRoundData_works_correctly_for_a_balanced_pool(
        uint256 balanceScaleFactor,
        uint256 ethPrice
    ) public {
        balanceScaleFactor = (balanceScaleFactor % (100e18 - 1e18)) + 1e18;
        ethPrice = (ethPrice % (100000e8 - 100e8)) + 100e8;

        (, uint256[] memory balances,) = balancerMock.getPoolTokens(POOL_ID);

        uint256 expectedPrice = 0;

        uint256 ethValue = (4_000_000 * 1e8 * balanceScaleFactor) / 1e18;

        uint256 ethBalance = (ethValue * 1e18) / ethPrice;

        balances[0] = ethBalance;
        expectedPrice += (balances[0] * ethPrice) / 1e18;

        balances[1] = (balances[1] * balanceScaleFactor) / 1e18;
        expectedPrice += (balances[1] * 1e8) / 1e18;

        balances[2] = (balances[2] * balanceScaleFactor) / 1e18;
        expectedPrice += (balances[2] * 1e8) / 1e18;

        balances[3] = (balances[3] * balanceScaleFactor) / 1e18;
        expectedPrice += (balances[3] * 1e8) / 1e6;

        expectedPrice = (expectedPrice * 1e18) / (1_000_000 * 10 ** 18);

        balancerMock.setAssetBalances(POOL_ID, balances);

        pfm1.setPrice(int256(ethPrice));

        uint256 ios = bptPriceFeed.getInvariantOverSupply();

        bptPriceFeed.setLimiter(ios);

        (, int256 answer,,,) = bptPriceFeed.latestRoundData();

        assertLe(expectedPrice - uint256(answer), 100, "Price discrepancy more than than 1e-6 USD");
    }

    function test_OBWLP_04_latestRoundData_returns_discounted_value_for_imbalanced_pool(
        uint256 balanceScaleFactor,
        uint256 price0,
        uint256 price1,
        uint256 price2,
        uint256 price3
    ) external {
        balanceScaleFactor = (balanceScaleFactor % (100e18 - 1e18)) + 1e18;
        price0 = (price0 % (100000e8 - 100e8)) + 100e8;
        price1 = (price1 % (2e8 - 9e7)) + 9e7;
        price2 = (price2 % (2e8 - 9e7)) + 9e7;
        price3 = (price3 % (2e8 - 9e7)) + 9e7;

        (, uint256[] memory balances,) = balancerMock.getPoolTokens(POOL_ID);

        uint256 expectedPrice = 0;

        balances[0] = (balances[0] * balanceScaleFactor) / 1e18;
        expectedPrice += (balances[0] * price0) / 1e18;

        balances[1] = (balances[1] * balanceScaleFactor) / 1e18;
        expectedPrice += (balances[1] * price1) / 1e18;

        balances[2] = (balances[2] * balanceScaleFactor) / 1e18;
        expectedPrice += (balances[2] * price2) / 1e18;

        balances[3] = (balances[3] * balanceScaleFactor) / 1e18;
        expectedPrice += (balances[3] * price3) / 1e6;

        expectedPrice = (expectedPrice * 1e18) / (1_000_000 * 10 ** 18);

        balancerMock.setAssetBalances(POOL_ID, balances);

        pfm1.setPrice(int256(price0));
        pfm2.setPrice(int256(price1));
        pfm3.setPrice(int256(price2));
        pfm4.setPrice(int256(price3));

        uint256 ios = bptPriceFeed.getInvariantOverSupply();

        bptPriceFeed.setLimiter(ios);

        (, int256 answer,,,) = bptPriceFeed.latestRoundData();

        assertLe(uint256(answer), expectedPrice, "Returned value larger than expected price");
    }

    function test_OBWLP_05_latestRoundData_reverts_for_out_of_bounds_value() public {
        (, uint256[] memory balances,) = balancerMock.getPoolTokens(POOL_ID);

        balances[0] = balances[0] / 2;
        balances[1] = balances[1] / 2;
        balances[2] = balances[2] / 2;
        balances[3] = balances[3] / 2;

        balancerMock.setAssetBalances(POOL_ID, balances);

        evm.expectRevert(ValueOutOfRangeException.selector);
        bptPriceFeed.latestRoundData();

        balances[0] = balances[0] * 4;
        balances[1] = balances[1] * 4;
        balances[2] = balances[2] * 4;
        balances[3] = balances[3] * 4;

        balancerMock.setAssetBalances(POOL_ID, balances);

        (, int256 answer,,,) = bptPriceFeed.latestRoundData();

        assertEq(uint256(answer), 1020000000 - 1, "Upper bound value was not used");
    }

    function test_OBWLP_06_setLimiter_reverts_if_current_value_out_of_new_bounds() public {
        uint256 ios = bptPriceFeed.getInvariantOverSupply();

        evm.expectRevert(IncorrectLimitsException.selector);
        bptPriceFeed.setLimiter(ios * 2);

        evm.expectRevert(IncorrectLimitsException.selector);
        bptPriceFeed.setLimiter(ios / 2);
    }
}
