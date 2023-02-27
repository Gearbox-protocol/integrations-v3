// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceFeedType} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceFeedType.sol";
import {LPPriceFeed} from "@gearbox-protocol/core-v2/contracts/oracles/LPPriceFeed.sol";

import {IBalancerV2VaultGetters} from "../../integrations/balancer/IBalancerV2Vault.sol";
import {IBalancerWeightedPool} from "../../integrations/balancer/IBalancerWeightedPool.sol";
import {FixedPoint} from "../../integrations/balancer/FixedPoint.sol";

// EXCEPTIONS
import {
    ZeroAddressException, NotImplementedException
} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

/// @title Balancer Weighted pool LP price feed parameters and setup
/// @notice Each variable set is sorted in order of ascending asset weights in Balancer pool
///         This is needed to optimize the number of FixedPoint exponentiations, which are gas-intensive
contract BPTWeightedPriceFeedSetup {
    error TokenArraysLengthMismatchException();

    /// @dev Chainlink price feed for pool asset 0
    AggregatorV3Interface public immutable priceFeed0;

    /// @dev Chainlink price feed for pool asset 1
    AggregatorV3Interface public immutable priceFeed1;

    /// @dev Chainlink price feed for pool asset 2
    AggregatorV3Interface public immutable priceFeed2;

    /// @dev Chainlink price feed for pool asset 3
    AggregatorV3Interface public immutable priceFeed3;

    /// @dev Chainlink price feed for pool asset 4
    AggregatorV3Interface public immutable priceFeed4;

    /// @dev Chainlink price feed for pool asset 5
    AggregatorV3Interface public immutable priceFeed5;

    /// @dev Chainlink price feed for pool asset 6
    AggregatorV3Interface public immutable priceFeed6;

    /// @dev Chainlink price feed for pool asset 7
    AggregatorV3Interface public immutable priceFeed7;

    /// @dev Asset 0
    IERC20 public immutable asset0;

    /// @dev Asset 1
    IERC20 public immutable asset1;

    /// @dev Asset 2
    IERC20 public immutable asset2;

    /// @dev Asset 3
    IERC20 public immutable asset3;

    /// @dev Asset 4
    IERC20 public immutable asset4;

    /// @dev Asset 5
    IERC20 public immutable asset5;

    /// @dev Asset 6
    IERC20 public immutable asset6;

    /// @dev Asset 7
    IERC20 public immutable asset7;

    uint8 immutable decimals0;

    uint8 immutable decimals1;

    uint8 immutable decimals2;

    uint8 immutable decimals3;

    uint8 immutable decimals4;

    uint8 immutable decimals5;

    uint8 immutable decimals6;

    uint8 immutable decimals7;

    /// @dev Index of the asset in the pool that is ranked 1st when ordered by ascending weights
    uint256 immutable index0;

    /// @dev Index of the asset in the pool that is ranked 2nd when ordered by ascending weights
    uint256 immutable index1;

    /// @dev Index of the asset in the pool that is ranked 3rd when ordered by ascending weights
    uint256 immutable index2;

    /// @dev Index of the asset in the pool that is ranked 4th when ordered by ascending weights
    uint256 immutable index3;

    /// @dev Index of the asset in the pool that is ranked 5th when ordered by ascending weights
    uint256 immutable index4;

    /// @dev Index of the asset in the pool that is ranked 6th when ordered by ascending weights
    uint256 immutable index5;

    /// @dev Index of the asset in the pool that is ranked 7th when ordered by ascending weights
    uint256 immutable index6;

    /// @dev Index of the asset in the pool that is ranked 8th when ordered by ascending weights
    uint256 immutable index7;

    /// @dev Weight for asset 0 (in 1e18 fixed point format)
    uint256 public immutable normalizedWeight0;

    /// @dev Weight for asset 1 (in 1e18 fixed point format)
    uint256 public immutable normalizedWeight1;

    /// @dev Weight for asset 2 (in 1e18 fixed point format)
    uint256 public immutable normalizedWeight2;

    /// @dev Weight for asset 3 (in 1e18 fixed point format)
    uint256 public immutable normalizedWeight3;

    /// @dev Weight for asset 4 (in 1e18 fixed point format)
    uint256 public immutable normalizedWeight4;

    /// @dev Weight for asset 5 (in 1e18 fixed point format)
    uint256 public immutable normalizedWeight5;

    /// @dev Weight for asset 6 (in 1e18 fixed point format)
    uint256 public immutable normalizedWeight6;

    /// @dev Weight for asset 7 (in 1e18 fixed point format)
    uint256 public immutable normalizedWeight7;

    /// @dev Address of the BPT's pool on Balancer
    IBalancerWeightedPool public immutable balancerPool;

    /// @dev Address of Balancer V2 Vault
    IBalancerV2VaultGetters public immutable balancerVault;

    /// @dev ID of the BPT's pool on Balancer
    bytes32 public immutable poolId;

    /// @dev Number of assets in the pool
    uint256 public immutable numAssets;

    /// @param _balancerVault Address of the Balancer V2 vault
    /// @param _balancerPool Address of the BPT's associated pool
    /// @param priceFeeds Array of price feeds (in the same order as assets in the pool!)
    /// @notice During deployment, the assets and price feeds are reshuffled
    ///         in the order of ascending weights for each asset. Everything is saved into immutable
    ///         variables for efficiency
    constructor(address _balancerVault, address _balancerPool, address[] memory priceFeeds) {
        if (_balancerVault == address(0) || _balancerPool == address(0)) {
            revert ZeroAddressException();
        } // F: [OBWLP-2]

        {
            uint256 len = priceFeeds.length;

            for (uint256 i = 0; i < len;) {
                if (priceFeeds[i] == address(0)) {
                    revert ZeroAddressException(); // F: [OBWLP-2]
                }

                unchecked {
                    ++i;
                }
            }
        }

        balancerPool = IBalancerWeightedPool(_balancerPool); // F: [OBWLP-1]
        balancerVault = IBalancerV2VaultGetters(_balancerVault); // F: [OBWLP-1]

        poolId = balancerPool.getPoolId(); // F: [OBWLP-1]

        (IERC20[] memory tokens,,) = balancerVault.getPoolTokens(poolId);

        uint256[] memory weights = balancerPool.getNormalizedWeights();

        if (tokens.length != weights.length || weights.length != priceFeeds.length) {
            revert TokenArraysLengthMismatchException();
        }

        numAssets = tokens.length;

        uint256[] memory indices;

        (tokens, weights, priceFeeds, indices) = _getSortedArrays(tokens, weights, priceFeeds);

        asset0 = tokens[0]; // F: [OBWLP-1]
        asset1 = tokens[1]; // F: [OBWLP-1]
        asset2 = numAssets >= 3 ? tokens[2] : IERC20(address(0)); // F: [OBWLP-1]
        asset3 = numAssets >= 4 ? tokens[3] : IERC20(address(0)); // F: [OBWLP-1]
        asset4 = numAssets >= 5 ? tokens[4] : IERC20(address(0)); // F: [OBWLP-1]
        asset5 = numAssets >= 6 ? tokens[5] : IERC20(address(0)); // F: [OBWLP-1]
        asset6 = numAssets >= 7 ? tokens[6] : IERC20(address(0)); // F: [OBWLP-1]
        asset7 = numAssets >= 8 ? tokens[7] : IERC20(address(0)); // F: [OBWLP-1]

        decimals0 = IERC20Metadata(address(tokens[0])).decimals(); // F: [OBWLP-1]
        decimals1 = IERC20Metadata(address(tokens[1])).decimals(); // F: [OBWLP-1]
        decimals2 = numAssets >= 3 ? IERC20Metadata(address(tokens[2])).decimals() : 0; // F: [OBWLP-1]
        decimals3 = numAssets >= 4 ? IERC20Metadata(address(tokens[3])).decimals() : 0; // F: [OBWLP-1]
        decimals4 = numAssets >= 5 ? IERC20Metadata(address(tokens[4])).decimals() : 0; // F: [OBWLP-1]
        decimals5 = numAssets >= 6 ? IERC20Metadata(address(tokens[5])).decimals() : 0; // F: [OBWLP-1]
        decimals6 = numAssets >= 7 ? IERC20Metadata(address(tokens[6])).decimals() : 0; // F: [OBWLP-1]
        decimals7 = numAssets >= 8 ? IERC20Metadata(address(tokens[7])).decimals() : 0; // F: [OBWLP-1]

        normalizedWeight0 = weights[0]; // F: [OBWLP-1]
        normalizedWeight1 = weights[1]; // F: [OBWLP-1]
        normalizedWeight2 = numAssets >= 3 ? weights[2] : 0; // F: [OBWLP-1]
        normalizedWeight3 = numAssets >= 4 ? weights[3] : 0; // F: [OBWLP-1]
        normalizedWeight4 = numAssets >= 5 ? weights[4] : 0; // F: [OBWLP-1]
        normalizedWeight5 = numAssets >= 6 ? weights[5] : 0; // F: [OBWLP-1]
        normalizedWeight6 = numAssets >= 7 ? weights[6] : 0; // F: [OBWLP-1]
        normalizedWeight7 = numAssets >= 8 ? weights[7] : 0; // F: [OBWLP-1]

        priceFeed0 = AggregatorV3Interface(priceFeeds[0]); // F: [OBWLP-1]
        priceFeed1 = AggregatorV3Interface(priceFeeds[1]); // F: [OBWLP-1]
        priceFeed2 = numAssets >= 3 ? AggregatorV3Interface(priceFeeds[2]) : AggregatorV3Interface(address(0)); // F: [OBWLP-1]
        priceFeed3 = numAssets >= 4 ? AggregatorV3Interface(priceFeeds[3]) : AggregatorV3Interface(address(0)); // F: [OBWLP-1]
        priceFeed4 = numAssets >= 5 ? AggregatorV3Interface(priceFeeds[4]) : AggregatorV3Interface(address(0)); // F: [OBWLP-1]
        priceFeed5 = numAssets >= 6 ? AggregatorV3Interface(priceFeeds[5]) : AggregatorV3Interface(address(0)); // F: [OBWLP-1]
        priceFeed6 = numAssets >= 7 ? AggregatorV3Interface(priceFeeds[6]) : AggregatorV3Interface(address(0)); // F: [OBWLP-1]
        priceFeed7 = numAssets >= 8 ? AggregatorV3Interface(priceFeeds[7]) : AggregatorV3Interface(address(0)); // F: [OBWLP-1]

        index0 = indices[0]; // F: [OBWLP-1]
        index1 = indices[1]; // F: [OBWLP-1]
        index2 = numAssets >= 3 ? indices[2] : 0; // F: [OBWLP-1]
        index3 = numAssets >= 4 ? indices[3] : 0; // F: [OBWLP-1]
        index4 = numAssets >= 5 ? indices[4] : 0; // F: [OBWLP-1]
        index5 = numAssets >= 6 ? indices[5] : 0; // F: [OBWLP-1]
        index6 = numAssets >= 7 ? indices[6] : 0; // F: [OBWLP-1]
        index7 = numAssets >= 8 ? indices[7] : 0; // F: [OBWLP-1]
    }

    /// @dev Internal function that sorts tokens, weights and price feeds in the order of ascending weights,
    ///      and also returns the resulting permutation to be later used for realigning balances
    function _getSortedArrays(IERC20[] memory tokens, uint256[] memory weights, address[] memory priceFeeds)
        internal
        pure
        returns (IERC20[] memory, uint256[] memory, address[] memory, uint256[] memory)
    {
        uint256 len = weights.length;

        uint256[] memory indices = new uint256[](len);

        for (uint256 i; i < len;) {
            indices[i] = i;

            unchecked {
                ++i;
            }
        }

        _quickIndices(weights, indices, 0, len - 1);

        IERC20[] memory sortedTokens = new IERC20[](len);
        address[] memory sortedPFs = new address[](len);

        for (uint256 i = 0; i < len;) {
            sortedTokens[i] = tokens[indices[i]];
            sortedPFs[i] = priceFeeds[indices[i]];

            unchecked {
                ++i;
            }
        }

        return (sortedTokens, weights, sortedPFs, indices);
    }

    /// @dev Internal function that runs QuickSort on data and also returns the resulting permutation
    function _quickIndices(uint256[] memory data, uint256[] memory indices, uint256 low, uint256 high) internal pure {
        if (low < high) {
            uint256 pVal = data[(low + high) / 2];

            uint256 i = low;
            uint256 j = high;
            for (;;) {
                while (data[i] < pVal) i++;
                while (data[j] > pVal) j--;
                if (i >= j) break;
                if (data[i] != data[j]) {
                    (data[i], data[j]) = (data[j], data[i]);
                    (indices[i], indices[j]) = (indices[j], indices[i]);
                }
                i++;
                j--;
            }
            if (low < j) _quickIndices(data, indices, low, j);
            j++;
            if (j < high) _quickIndices(data, indices, j, high);
        }
    }

    /// @dev Returns weights as an array
    function _getWeightsArray() internal view returns (uint256[] memory weights) {
        weights = new uint256[](numAssets);

        weights[0] = normalizedWeight0;
        weights[1] = normalizedWeight1;
        if (numAssets >= 3) weights[2] = normalizedWeight2;
        if (numAssets >= 4) weights[3] = normalizedWeight3;
        if (numAssets >= 5) weights[4] = normalizedWeight4;
        if (numAssets >= 6) weights[5] = normalizedWeight5;
        if (numAssets >= 7) weights[6] = normalizedWeight6;
        if (numAssets >= 8) weights[7] = normalizedWeight7;
    }

    /// @dev Returns price feeds as an array
    function _getPriceFeedsArray() internal view returns (AggregatorV3Interface[] memory priceFeeds) {
        priceFeeds = new AggregatorV3Interface[](numAssets);

        priceFeeds[0] = priceFeed0;
        priceFeeds[1] = priceFeed1;
        if (numAssets >= 3) priceFeeds[2] = priceFeed2;
        if (numAssets >= 4) priceFeeds[3] = priceFeed3;
        if (numAssets >= 5) priceFeeds[4] = priceFeed4;
        if (numAssets >= 6) priceFeeds[5] = priceFeed5;
        if (numAssets >= 7) priceFeeds[6] = priceFeed6;
        if (numAssets >= 8) priceFeeds[7] = priceFeed7;
    }
}
