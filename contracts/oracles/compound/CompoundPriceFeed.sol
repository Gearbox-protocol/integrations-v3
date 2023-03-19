// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {LPPriceFeed, PriceFeedType} from "../LPPriceFeed.sol";
import {ICToken} from "../../integrations/compound/ICToken.sol";

// EXCEPTIONS
import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

uint256 constant RANGE_WIDTH = 200; // 2%

/// @title Compound V2 cToken price feed
contract CompoundPriceFeed is LPPriceFeed {
    /// @dev Chainlink price feed for the underlying token
    AggregatorV3Interface public immutable priceFeed;

    /// @dev Address of the cToken to compute prices for
    ICToken public immutable cToken;

    /// @dev Scale of the cToken's exchangeRate
    uint256 public constant decimalsDivider = WAD;

    PriceFeedType public constant override priceFeedType = PriceFeedType.COMPOUND_ORACLE;
    uint256 public constant override version = 1;

    /// @dev Whether to skip price sanity checks.
    /// @notice Always set to true for LP price feeds,
    ///         since they perform their own sanity checks
    bool public constant override skipPriceCheck = true;

    constructor(address addressProvider, address _cToken, address _priceFeed)
        LPPriceFeed(
            addressProvider,
            RANGE_WIDTH,
            _cToken != address(0) ? string(abi.encodePacked(ICToken(_cToken).name(), " priceFeed")) : ""
        )
    {
        if (_cToken == address(0) || _priceFeed == address(0)) {
            revert ZeroAddressException();
        }

        cToken = ICToken(_cToken);
        priceFeed = AggregatorV3Interface(_priceFeed);

        uint256 exchangeRate = cToken.exchangeRateCurrent();
        _setLimiter(exchangeRate);
    }

    /// @dev Returns the USD price of the cToken
    /// @notice Computes the cToken price as (price(underlying) * exchangeRate)
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed.latestRoundData();

        // Sanity check for chainlink pricefeed
        _checkAnswer(roundId, answer, updatedAt, answeredInRound);

        uint256 exchangeRate = cToken.exchangeRateStored();

        // Checks that exchangeRate is within bounds
        exchangeRate = _checkAndUpperBoundValue(exchangeRate);

        answer = int256((exchangeRate * uint256(answer)) / decimalsDivider);
    }

    function _checkCurrentValueInBounds(uint256 _lowerBound, uint256 _uBound) internal view override returns (bool) {
        uint256 rate = cToken.exchangeRateStored();
        if (rate < _lowerBound || rate > _uBound) {
            return false;
        }
        return true;
    }
}
