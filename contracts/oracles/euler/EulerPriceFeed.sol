// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { PriceFeedType } from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceFeedType.sol";
import { LPPriceFeed } from "@gearbox-protocol/core-v2/contracts/oracles/LPPriceFeed.sol";
import { WAD } from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import { IEToken } from "../../integrations/euler/IEToken.sol";

// EXCEPTIONS
import { ZeroAddressException } from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

uint256 constant RANGE_WIDTH = 200; // 2%

/// @title Euler price feed
contract EulerPriceFeed is LPPriceFeed {
    /// @dev Chainlink price feed for the underlying token
    AggregatorV3Interface public immutable priceFeed;

    /// @dev Address of the eToken to compute prices for
    IEToken public immutable eToken;

    /// @dev Scale of the eToken's exchange rate
    uint256 public immutable decimalsDivider;

    PriceFeedType public constant override priceFeedType =
        PriceFeedType.EULER_ORACLE;
    uint256 public constant override version = 1;

    /// @dev Whether to skip price sanity checks.
    /// @notice Always set to true for LP price feeds,
    ///         since they perform their own sanity checks
    bool public constant override skipPriceCheck = true;

    constructor(
        address addressProvider,
        address _eToken,
        address _priceFeed
    )
        LPPriceFeed(
            addressProvider,
            RANGE_WIDTH,
            _eToken != address(0)
                ? string(
                    abi.encodePacked(IEToken(_eToken).name(), " priceFeed")
                )
                : ""
        )
    {
        if (_eToken == address(0) || _priceFeed == address(0))
            revert ZeroAddressException();

        eToken = IEToken(_eToken);
        priceFeed = AggregatorV3Interface(_priceFeed);

        decimalsDivider =
            10 ** IERC20Metadata(eToken.underlyingAsset()).decimals();
        uint256 exchangeRate = _exchangeRate();
        _setLimiter(exchangeRate);
    }

    /// @dev Returns the USD price of the eToken
    /// @notice Computes the eToken price as (price(underlying) * exchangeRate)
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
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed
            .latestRoundData();

        // Sanity check for chainlink pricefeed
        _checkAnswer(roundId, answer, updatedAt, answeredInRound);

        uint256 exchangeRate = _exchangeRate();

        // Checks that exchangeRate is within bounds
        exchangeRate = _checkAndUpperBoundValue(exchangeRate);

        answer = int256((exchangeRate * uint256(answer)) / decimalsDivider);
    }

    function _checkCurrentValueInBounds(
        uint256 _lowerBound,
        uint256 _uBound
    ) internal view override returns (bool) {
        uint256 rate = _exchangeRate();
        if (rate < _lowerBound || rate > _uBound) {
            return false;
        }
        return true;
    }

    function _exchangeRate() internal view returns (uint256) {
        return eToken.convertBalanceToUnderlying(WAD);
    }
}
