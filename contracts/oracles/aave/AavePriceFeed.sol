// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceFeedType} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceFeedType.sol";
import {LPPriceFeed} from "@gearbox-protocol/core-v3/contracts/oracles/LPPriceFeed.sol";
import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {IWrappedAToken} from "../../interfaces/aave/IWrappedAToken.sol";

// EXCEPTIONS
import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

uint256 constant RANGE_WIDTH = 200; // 2%

/// @title Aave V2 wrapped aToken price feed
contract AavePriceFeed is LPPriceFeed {
    /// @dev Chainlink price feed for the aToken's underlying token
    AggregatorV3Interface public immutable priceFeed;

    /// @dev Address of the waToken to compute prices for
    IWrappedAToken public immutable waToken;

    /// @dev Scale of the waToken's exchange rate
    uint256 public constant decimalsDivider = WAD;

    PriceFeedType public constant override priceFeedType = PriceFeedType.AAVE_ORACLE;
    uint256 public constant override version = 1;

    /// @dev Whether to skip price sanity checks.
    /// @notice Always set to true for LP price feeds,
    ///         since they perform their own sanity checks
    bool public constant override skipPriceCheck = true;

    constructor(address addressProvider, address _waToken, address _priceFeed)
        LPPriceFeed(
            addressProvider,
            RANGE_WIDTH,
            _waToken != address(0) ? string(abi.encodePacked(IWrappedAToken(_waToken).name(), " priceFeed")) : ""
        )
    {
        if (_waToken == address(0) || _priceFeed == address(0)) {
            revert ZeroAddressException();
        }

        waToken = IWrappedAToken(_waToken);
        priceFeed = AggregatorV3Interface(_priceFeed);

        uint256 exchangeRate = waToken.exchangeRate();
        _setLimiter(exchangeRate);
    }

    /// @dev Returns the USD price of the waToken
    /// @notice Computes the waToken price as (price(underlying) * exchangeRate)
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed.latestRoundData();

        // Sanity check for chainlink pricefeed
        _checkAnswer(roundId, answer, updatedAt, answeredInRound);

        uint256 exchangeRate = waToken.exchangeRate();

        // Checks that exchangeRate is within bounds
        exchangeRate = _checkAndUpperBoundValue(exchangeRate);

        answer = int256((exchangeRate * uint256(answer)) / decimalsDivider);
    }

    function _checkCurrentValueInBounds(uint256 _lowerBound, uint256 _uBound) internal view override returns (bool) {
        uint256 rate = waToken.exchangeRate();
        if (rate < _lowerBound || rate > _uBound) {
            return false;
        }
        return true;
    }
}
