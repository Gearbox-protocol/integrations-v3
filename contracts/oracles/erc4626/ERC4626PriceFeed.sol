// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {LPPriceFeed, PriceFeedType} from "../LPPriceFeed.sol";

// EXCEPTIONS
import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

uint256 constant RANGE_WIDTH = 200; // 2%

/// @title ERC4626 vault shares price feed
contract ERC4626PriceFeed is LPPriceFeed {
    /// @dev Chainlink price feed for the vault's underlying
    AggregatorV3Interface public immutable priceFeed;

    /// @dev Address of the vault to compute prices for
    IERC4626 public immutable vault;

    /// @dev Amount of shares comprising a single unit (accounting for decimals)
    uint256 public immutable vaultShareUnit;

    /// @dev Amount of underlying comprising a single unit (accounting for decimals)
    uint256 public immutable underlyingUnit;

    PriceFeedType public constant override priceFeedType = PriceFeedType.ERC4626_VAULT_ORACLE;
    uint256 public constant override version = 1;

    /// @dev Whether to skip price sanity checks.
    /// @notice Always set to true for LP price feeds,
    ///         since they perform their own sanity checks
    bool public constant override skipPriceCheck = true;

    constructor(address addressProvider, address _vault, address _priceFeed)
        LPPriceFeed(
            addressProvider,
            RANGE_WIDTH,
            _vault != address(0) ? string(abi.encodePacked(IERC20Metadata(_vault).name(), " priceFeed")) : ""
        )
    {
        if (_vault == address(0) || _priceFeed == address(0)) {
            revert ZeroAddressException();
        }

        vault = IERC4626(_vault);
        priceFeed = AggregatorV3Interface(_priceFeed);

        vaultShareUnit = 10 ** vault.decimals();
        underlyingUnit = 10 ** IERC20Metadata(vault.asset()).decimals();

        uint256 assetsPerShare = vault.convertToAssets(vaultShareUnit);
        _setLimiter(assetsPerShare);
    }

    /// @dev Returns the USD price of the pool's share
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed.latestRoundData();

        // Sanity check for chainlink pricefeed
        _checkAnswer(roundId, answer, updatedAt, answeredInRound);

        uint256 assetsPerShare = vault.convertToAssets(vaultShareUnit);

        assetsPerShare = _checkAndUpperBoundValue(assetsPerShare);

        answer = int256((assetsPerShare * uint256(answer)) / underlyingUnit);
    }

    function _checkCurrentValueInBounds(uint256 _lowerBound, uint256 _uBound) internal view override returns (bool) {
        uint256 assetsPerShare = vault.convertToAssets(vaultShareUnit);
        if (assetsPerShare < _lowerBound || assetsPerShare > _uBound) {
            return false;
        }
        return true;
    }
}
