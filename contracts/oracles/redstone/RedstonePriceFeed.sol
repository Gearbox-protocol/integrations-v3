// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {RedstoneConsumerNumericBase} from
    "@redstone-finance/evm-connector/contracts/core/RedstoneConsumerNumericBase.sol";
import {PriceFeedType, IPriceFeedType} from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceFeedType.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";
import {IUpdatablePriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "forge-std/console.sol";

interface IRedstonePriceFeedExceptions {
    /// @dev Thrown no non-zero signers are passed
    ///      or the signer set is smaller than required threshold
    error InvalidSignerSetException();

    /// @dev Thrown when the validated price value is zero
    error ZeroPriceException();

    /// @dev Thrown when attempting to access a price value
    ///      that wasn't submitted in the current block
    error RedstonePriceStaleException();

    /// @dev Thrown when attempting to push an update
    ///      with the payload that is older than the last
    ///      update payload, or too far from the current block
    ///      timestamp
    error RedstonePayloadTimestampIncorrect();

    /// @dev Thrown when data package timestamp is not equal to expected
    ///      payload timestamp
    error DataPackageTimestampIncorrect();
}

interface IRedstonePriceFeedEvents {
    /// @dev Emitted when a successful price update is pushed
    event PriceUpdated(uint256 price);
}

contract RedstonePriceFeed is
    RedstoneConsumerNumericBase,
    IUpdatablePriceFeed,
    IPriceFeedType,
    AggregatorV3Interface,
    IRedstonePriceFeedExceptions,
    IRedstonePriceFeedEvents
{
    using SafeCast for uint256;

    /// @notice Max period that the payload can be backward in time relative to the block
    uint256 public constant DEFAULT_MAX_DATA_TIMESTAMP_DELAY_SECONDS = 3 minutes;

    /// @notice Max period that the payload can be forward in time relative to the block
    uint256 public constant DEFAULT_MAX_DATA_TIMESTAMP_AHEAD_SECONDS = 1 minutes;

    /// @notice Max time that the price feed will return the last update's price for
    ///         If more time elapse since last update, the price feed will revert
    uint256 public constant DEFAULT_PRICE_EXPIRATION_TIME = 4 minutes;

    /// @notice Price feed description
    string public override description;

    /// @notice Decimals of the price feed's returned value (always 8 for USD price feeds)
    uint8 public constant override decimals = 8;

    /// @notice ID of the asset in Redstone's payload
    bytes32 public immutable dataFeedId;

    /// @notice Authorized payload signer at index 0
    address public immutable signerAddress0;

    /// @notice Authorized payload signer at index 1
    address public immutable signerAddress1;

    /// @notice Authorized payload signer at index 2
    address public immutable signerAddress2;

    /// @notice Authorized payload signer at index 3
    address public immutable signerAddress3;

    /// @notice Authorized payload signer at index 4
    address public immutable signerAddress4;

    /// @notice Authorized payload signer at index 5
    address public immutable signerAddress5;

    /// @notice Authorized payload signer at index 6
    address public immutable signerAddress6;

    /// @notice Authorized payload signer at index 7
    address public immutable signerAddress7;

    /// @notice Authorized payload signer at index 8
    address public immutable signerAddress8;

    /// @notice Authorized payload signer at index 9
    address public immutable signerAddress9;

    /// @notice Minimal number of unique signatures from authorized signers
    ///         required to validate a payload
    uint8 public immutable signersThreshold;

    /// @notice The last stored price value
    uint128 public lastPrice;

    /// @notice The timestamp of the last update's payload
    uint40 public lastPayloadTimestamp;

    /// @dev Contract version
    uint256 public constant override version = 3_00;

    /// @dev Whether to skip price sanity checks.
    /// @notice Always set to true for Redstone oracle,
    ///         since price updates always check price value to be zero
    ///         and extra metadata from `latestRoundData()` is returned as zero
    bool public constant override skipPriceCheck = true;

    PriceFeedType public constant override priceFeedType = PriceFeedType.REDSTONE_ORACLE;

    constructor(string memory tokenSymbol, bytes32 _dataFeedId, address[10] memory _signers, uint8 _signersThreshold) {
        if (_signersThreshold > 10) revert InvalidSignerSetException();
        for (uint256 i = 0; i < _signersThreshold; ++i) {
            if (_signers[i] == address(0)) revert InvalidSignerSetException();
        }

        dataFeedId = _dataFeedId;

        signerAddress0 = _signers[0];
        signerAddress1 = _signers[1];
        signerAddress2 = _signers[2];
        signerAddress3 = _signers[3];
        signerAddress4 = _signers[4];
        signerAddress5 = _signers[5];
        signerAddress6 = _signers[6];
        signerAddress7 = _signers[7];
        signerAddress8 = _signers[8];
        signerAddress9 = _signers[9];

        signersThreshold = _signersThreshold;

        description = string(abi.encodePacked(tokenSymbol, " Redstone Price Feed"));
    }

    /// @notice Returns the number of unique signatures required to validate a payload
    function getUniqueSignersThreshold() public view virtual override returns (uint8) {
        return signersThreshold;
    }

    /// @notice Returns the index of the provided signer or reverts if the address is not a signer
    function getAuthorisedSignerIndex(address signerAddress) public view virtual override returns (uint8) {
        if (signerAddress == signerAddress0) return 0;
        if (signerAddress == signerAddress1) return 1;
        if (signerAddress == signerAddress2) return 2;
        if (signerAddress == signerAddress3) return 3;
        if (signerAddress == signerAddress4) return 4;
        if (signerAddress == signerAddress5) return 5;
        if (signerAddress == signerAddress6) return 6;
        if (signerAddress == signerAddress7) return 7;
        if (signerAddress == signerAddress8) return 8;
        if (signerAddress == signerAddress9) return 9;

        revert SignerNotAuthorised(signerAddress);
    }

    /// @notice Validates that a timestamp in a data package is valid
    /// @dev Sanity checks on the timestamp are performed earlier in the update,
    ///      when the lastPayloadTimestamp is being set
    /// @param receivedTimestampMilliseconds Timestamp in the data package, in milliseconds
    function validateTimestamp(uint256 receivedTimestampMilliseconds) public view override {
        uint256 receivedTimestampSeconds = receivedTimestampMilliseconds / 1000;

        if (receivedTimestampSeconds != lastPayloadTimestamp) {
            revert DataPackageTimestampIncorrect();
        }
    }

    /// @dev Validates that the expected payload timestamp is not older than the last payload's,
    ///      and not too far from the current block's
    /// @param expectedPayloadTimestamp Timestamp expected to be in all of the incoming payload's
    ///                                 packages
    function _validateExpectedPayloadTimestamp(uint256 expectedPayloadTimestamp) internal view {
        if ((block.timestamp < expectedPayloadTimestamp)) {
            if ((expectedPayloadTimestamp - block.timestamp) > DEFAULT_MAX_DATA_TIMESTAMP_AHEAD_SECONDS) {
                revert RedstonePayloadTimestampIncorrect();
            }
        } else if ((block.timestamp - expectedPayloadTimestamp) > DEFAULT_MAX_DATA_TIMESTAMP_DELAY_SECONDS) {
            revert RedstonePayloadTimestampIncorrect();
        }
    }

    /// @notice Returns a validated price value extracted from Redstone payload
    /// @dev A valid Redstone payload has to be attached to the function's normal calldata,
    ///      otherwise this would revert
    function getValidatedValue() public view returns (uint256) {
        return getOracleNumericValueFromTxMsg(dataFeedId);
    }

    /// @notice Saves validated price retrieved from the passed Redstone payload
    /// @param data A data blob with with 2 parts:
    ///             - A timestamp expected to be in all Redstone data packages
    ///             - Redstone payload with price update
    function updatePrice(bytes calldata data) external {
        (uint256 expectedPayloadTimestamp, bytes memory payload) = abi.decode(data, (uint256, bytes));

        // We want to minimize price update execution, in case, e.g., when several users submit
        // the same price update in a short span of time. So only updates with a larger payload timestamp
        // are fully validated and applied
        if (expectedPayloadTimestamp <= lastPayloadTimestamp) return;

        // We validate and set the payload timestamp here. Data packages' timestamps being equal
        // to the expected timestamp is checked in `validateTimestamp()`, which is called
        // from inside `getOracleNumericValueFromTxMsg`
        _validateExpectedPayloadTimestamp(expectedPayloadTimestamp);
        lastPayloadTimestamp = uint40(expectedPayloadTimestamp);

        // Prepare call to RedStone base function
        bytes memory encodedFunction = abi.encodeCall(this.getValidatedValue, ());
        bytes memory encodedFunctionWithRedstonePayload = abi.encodePacked(encodedFunction, payload);

        // Securely getting oracle value
        (bool success, bytes memory result) = address(this).staticcall(encodedFunctionWithRedstonePayload);

        // Parsing response
        uint256 priceValue;
        if (!success) {
            assembly {
                revert(add(32, result), mload(result))
            }
        }
        assembly {
            priceValue := mload(add(result, 32))
        }

        if (priceValue == 0) revert ZeroPriceException();

        if (priceValue != lastPrice) {
            lastPrice = priceValue.toUint128();
            emit PriceUpdated(priceValue);
        }
    }

    /// @notice Returns the USD price of the token (as the second returned value)
    /// @dev Since Redstone oracles do not adhere to Chainlink's interface, extra metadata is returned as 0
    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        if (lastPayloadTimestamp + DEFAULT_PRICE_EXPIRATION_TIME < block.timestamp) {
            revert RedstonePriceStaleException();
        }

        int256 answer = int256(uint256(lastPrice));

        return (0, answer, 0, 0, 0);
    }

    /// @dev Not implemented, since Gearbox does not use historical data
    function getRoundData(uint80) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert NotImplementedException();
    }
}
