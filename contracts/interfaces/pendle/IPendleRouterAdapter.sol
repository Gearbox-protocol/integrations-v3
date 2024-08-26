// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

import {ApproxParams, TokenInput, TokenOutput, LimitOrderData} from "../../integrations/pendle/IPendleRouter.sol";

enum PendleStatus {
    NOT_ALLOWED,
    ALLOWED,
    EXIT_ONLY
}

struct PendlePairStatus {
    address market;
    address inputToken;
    address pendleToken;
    PendleStatus status;
}

struct TokenDiffInput {
    address tokenIn;
    uint256 leftoverTokenIn;
}

struct TokenDiffOutput {
    address tokenOut;
    uint256 minRateRAY;
}

interface IPendleRouterAdapterEvents {
    event SetPairStatus(
        address indexed market, address indexed inputToken, address indexed pendleToken, PendleStatus allowed
    );
}

interface IPendleRouterAdapterExceptions {
    /// @notice Thrown when a pair is not allowed for swapping (direction-sensitive)
    error PairNotAllowedException();

    /// @notice Thrown when a pair is not allowed for PT to token redemption after expiry
    error RedemptionNotAllowedException();
}

/// @title PendleRouter adapter interface
interface IPendleRouterAdapter is IAdapter, IPendleRouterAdapterEvents, IPendleRouterAdapterExceptions {
    function swapExactTokenForPt(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input,
        LimitOrderData calldata limit
    ) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function swapDiffTokenForPt(
        address market,
        uint256 minRateRAY,
        ApproxParams calldata guessPtOut,
        TokenDiffInput calldata diffInput
    ) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function swapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    ) external returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function swapDiffPtForToken(address market, uint256 leftoverPt, TokenDiffOutput calldata diffOutput)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function redeemPyToToken(address receiver, address yt, uint256 netPyIn, TokenOutput calldata output)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    function redeemDiffPyToToken(address yt, uint256 leftoverPt, TokenDiffOutput calldata output)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable);

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Whether swaps for a particular pair in a Pendle market are supported (and which directions)
    function isPairAllowed(address market, address inputToken, address pendleToken)
        external
        view
        returns (PendleStatus status);

    /// @notice Changes the allowed status of several pairs
    function setPairStatusBatch(PendlePairStatus[] calldata pairs) external;

    /// @notice List of all pairs that are currently allowed in the adapter
    function getAllowedPairs() external view returns (PendlePairStatus[] memory pairs);

    /// @notice Mapping from PT to its canonical market
    function ptToMarket(address pt) external view returns (address market);
}
