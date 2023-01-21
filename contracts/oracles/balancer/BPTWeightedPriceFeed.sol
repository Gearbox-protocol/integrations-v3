// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { PriceFeedType } from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceFeedType.sol";
import { LPPriceFeed } from "@gearbox-protocol/core-v2/contracts/oracles/LPPriceFeed.sol";

import { BPTWeightedPriceFeedSetup } from "./BPTWeightedPriceFeedSetup.sol";
import { IBalancerV2VaultGetters } from "../../integrations/balancer/IBalancerV2Vault.sol";
import { IBalancerWeightedPool } from "../../integrations/balancer/IBalancerWeightedPool.sol";
import { FixedPoint } from "../../integrations/balancer/FixedPoint.sol";

// EXCEPTIONS
import { ZeroAddressException, NotImplementedException } from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

uint256 constant RANGE_WIDTH = 200; // 2%
uint256 constant DECIMALS = 10**18;
uint256 constant USD_FEED_DECIMALS = 10**8;

/// @title Balancer Weighted pool LP token price feed
contract BPTWeightedPriceFeed is BPTWeightedPriceFeedSetup, LPPriceFeed {
    using FixedPoint for uint256;

    PriceFeedType public constant override priceFeedType =
        PriceFeedType.ZERO_ORACLE;
    uint256 public constant override version = 2;

    /// @dev Whether to skip price sanity checks.
    /// @notice Always set to true for LP price feeds,
    ///         since they perform their own sanity checks
    bool public constant override skipPriceCheck = true;

    constructor(
        address addressProvider,
        address _balancerVault,
        address _balancerPool,
        address[] memory priceFeeds
    )
        LPPriceFeed(
            addressProvider,
            RANGE_WIDTH,
            _balancerPool != address(0)
                ? string(
                    abi.encodePacked(
                        IERC20Metadata(_balancerPool).name(),
                        " priceFeed"
                    )
                )
                : ""
        )
        BPTWeightedPriceFeedSetup(_balancerVault, _balancerPool, priceFeeds)
    {
        (, uint256[] memory balances, ) = balancerVault.getPoolTokens(poolId);
        uint256[] memory weights = _getWeightsArray();

        balances = _alignAndScaleBalanceArray(balances);

        _setLimiter(_computeInvariantOverSupply(balances, weights));
    }

    /// @dev Returns the supply of BPT token
    function _getBPTSupply() internal view returns (uint256 supply) {
        try balancerPool.getActualSupply() returns (uint256 actualSupply) {
            supply = actualSupply;
        } catch {
            supply = balancerPool.totalSupply();
        }
    }

    /// @dev Returns the Balancer pool invariant divided by BPT supply
    function _computeInvariantOverSupply(
        uint256[] memory balances,
        uint256[] memory weights
    ) internal view returns (uint256) {
        uint256 k = _computeInvariant(balances, weights);
        uint256 supply = _getBPTSupply();

        return k.divDown(supply);
    }

    /// @dev Returns the Balancer pool invariant
    /// @notice Computes the invariant in a way that optimizes the number
    ///         of exponentiations, which are gas-intensive
    function _computeInvariant(
        uint256[] memory balances,
        uint256[] memory weights
    ) internal pure returns (uint256 k) {
        k = FixedPoint.ONE;
        uint256 currentBase = FixedPoint.ONE;

        uint256 len = balances.length;

        for (uint256 i = 0; i < len; ) {
            currentBase = currentBase.mulDown(balances[i]);

            if (i == len - 1 || weights[i] != weights[i + 1]) {
                k = k.mulDown(currentBase.powDown(weights[i])); // F: [OBWLP-3,4]
                currentBase = FixedPoint.ONE;
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns the balance array sorted in the order of increasing asset weights
    function _alignAndScaleBalanceArray(uint256[] memory balances)
        internal
        view
        returns (uint256[] memory sortedBalances)
    {
        uint256 len = balances.length;

        sortedBalances = new uint256[](len);

        sortedBalances[0] = (balances[index0] * DECIMALS) / (10**decimals0);
        sortedBalances[1] = (balances[index1] * DECIMALS) / (10**decimals1);
        if (len >= 3)
            sortedBalances[2] = (balances[index2] * DECIMALS) / (10**decimals2);
        if (len >= 4)
            sortedBalances[3] = (balances[index3] * DECIMALS) / (10**decimals3);
        if (len >= 5)
            sortedBalances[4] = (balances[index4] * DECIMALS) / (10**decimals4);
        if (len >= 6)
            sortedBalances[5] = (balances[index5] * DECIMALS) / (10**decimals5);
        if (len >= 7)
            sortedBalances[6] = (balances[index6] * DECIMALS) / (10**decimals6);
        if (len >= 8)
            sortedBalances[7] = (balances[index7] * DECIMALS) / (10**decimals7);
    }

    /// @dev Returns the price of a single BPT in USD (with 8 decimals)
    /// @notice BPT price is computed as k * sum((p_i / w_i) ^ w_i) / S
    /// @notice Also does limiter checks on k / S, since this value must growing in a stable way from fees
    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        uint256 invariantOverSupply;
        uint256[] memory weights;

        {
            (, uint256[] memory balances, ) = balancerVault.getPoolTokens(
                poolId
            );
            weights = _getWeightsArray();

            balances = _alignAndScaleBalanceArray(balances); // F: [OBWLP-3,4]

            invariantOverSupply = _computeInvariantOverSupply(
                balances,
                weights
            );
            invariantOverSupply = _checkAndUpperBoundValue(invariantOverSupply); // F: [OBWLP-5]
        }

        AggregatorV3Interface[] memory priceFeeds = _getPriceFeedsArray();

        uint256 weightedPrice = FixedPoint.ONE;
        uint256 currentBase = FixedPoint.ONE;

        for (uint256 i = 0; i < numAssets; ) {
            (
                roundId,
                answer,
                startedAt,
                updatedAt,
                answeredInRound
            ) = priceFeeds[i].latestRoundData(); // F: [OBWLP-3,4]

            answer = (answer * int256(DECIMALS)) / int256(USD_FEED_DECIMALS);

            currentBase = currentBase.mulDown(
                uint256(answer).divDown(weights[i])
            );

            if (i == numAssets - 1 || weights[i] != weights[i + 1]) {
                weightedPrice = weightedPrice.mulDown(
                    currentBase.powDown(weights[i])
                ); // F: [OBWLP-3,4]
                currentBase = FixedPoint.ONE;
            }

            unchecked {
                ++i;
            }
        }

        answer = int256(invariantOverSupply.mulDown(weightedPrice)); // F: [OBWLP-3,4]

        answer = (answer * int256(USD_FEED_DECIMALS)) / int256(DECIMALS); // F: [OBWLP-3,4]
    }

    function getInvariantOverSupply() external view returns (uint256) {
        (, uint256[] memory balances, ) = balancerVault.getPoolTokens(poolId);
        uint256[] memory weights = _getWeightsArray();

        balances = _alignAndScaleBalanceArray(balances);

        return _computeInvariantOverSupply(balances, weights);
    }

    function _checkCurrentValueInBounds(uint256 _lowerBound, uint256 _uBound)
        internal
        view
        override
        returns (bool)
    {
        (, uint256[] memory balances, ) = balancerVault.getPoolTokens(poolId);
        uint256[] memory weights = _getWeightsArray();

        balances = _alignAndScaleBalanceArray(balances);

        uint256 ios = _computeInvariantOverSupply(balances, weights);
        if (ios < _lowerBound || ios > _uBound) {
            return false; // F: [OBWLP-6]
        }
        return true;
    }
}
