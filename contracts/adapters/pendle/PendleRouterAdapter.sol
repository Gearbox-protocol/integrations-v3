// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";

import {
    IPendleRouterAdapter,
    PendlePairStatus,
    TokenDiffInput,
    TokenDiffOutput,
    PendleStatus
} from "../../interfaces/pendle/IPendleRouterAdapter.sol";
import {
    IPendleRouter,
    IPendleMarket,
    IYToken,
    IPToken,
    SwapData,
    SwapType,
    TokenInput,
    TokenOutput,
    ApproxParams,
    LimitOrderData
} from "../../integrations/pendle/IPendleRouter.sol";

/// @title Pendle Router adapter
/// @notice Implements logic for interacting with the Pendle Router (swapping to / from PT only)
contract PendleRouterAdapter is AbstractAdapter, IPendleRouterAdapter {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 public constant override contractType = "AD_PENDLE_ROUTER";
    uint256 public constant override version = 3_10;

    /// @notice Mapping from (market, inputToken, pendleToken) to whether swaps are allowed, and which directions
    mapping(address => mapping(address => mapping(address => PendleStatus))) public isPairAllowed;

    /// @notice Mapping from (tokenOut, pendleToken) to whether redemption after expiry is allowed
    mapping(address => mapping(address => bool)) public isRedemptionAllowed;

    /// @notice Mapping from PT token to its canonical market
    mapping(address => address) public ptToMarket;

    /// @dev Set of hashes of all allowed pairs
    EnumerableSet.Bytes32Set internal _allowedPairHashes;

    /// @dev Mapping from pendle pair hash to the pair data and status
    mapping(bytes32 => PendlePairStatus) internal _hashToPendlePair;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _pendleRouter Pendle router address
    constructor(address _creditManager, address _pendleRouter) AbstractAdapter(_creditManager, _pendleRouter) {}

    /// @notice Swaps exact amount of input token to market's corresponding PT
    /// @param market Address of the market to swap in
    /// @param minPtOut Minimal amount of PT token out
    /// @param guessPtOut Search boundaries to save gas on PT amount calculation
    /// @param input Parameters of the input tokens
    /// @notice `receiver` and `limit` are ignored, since the recipient is always the Credit Account,
    ///         and Gearbox does not use Pendle's limit orders
    function swapExactTokenForPt(
        address,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input,
        LimitOrderData calldata
    )
        external
        creditFacadeOnly // U:[PEND-2]
        returns (bool useSafePrices)
    {
        (, address pt,) = IPendleMarket(market).readTokens();

        if (isPairAllowed[market][input.tokenIn][pt] != PendleStatus.ALLOWED) revert PairNotAllowedException(); // U:[PEND-3]

        address creditAccount = _creditAccount();

        LimitOrderData memory limit;

        TokenInput memory input_m;

        {
            input_m.tokenIn = input.tokenIn;
            input_m.netTokenIn = input.netTokenIn;
            input_m.tokenMintSy = input.tokenIn;
        }

        _executeSwapSafeApprove(
            input_m.tokenIn,
            abi.encodeCall(
                IPendleRouter.swapExactTokenForPt, (creditAccount, market, minPtOut, guessPtOut, input_m, limit)
            )
        ); // U:[PEND-3]

        useSafePrices = true;
    }

    /// @notice Swaps the entire balance of input token into PT, except the specified amount
    /// @param market Address of the market to swap in
    /// @param minRateRAY Minimal exchange rate of input to PT, in 1e27 format
    /// @param guessPtOut Search boundaries to save gas on PT amount calculation
    /// @param diffInput Input token parameters
    function swapDiffTokenForPt(
        address market,
        uint256 minRateRAY,
        ApproxParams calldata guessPtOut,
        TokenDiffInput calldata diffInput
    )
        external
        creditFacadeOnly // U:[PEND-2]
        returns (bool useSafePrices)
    {
        (, address pt,) = IPendleMarket(market).readTokens();

        if (isPairAllowed[market][diffInput.tokenIn][pt] != PendleStatus.ALLOWED) revert PairNotAllowedException(); // U:[PEND-4]

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(diffInput.tokenIn).balanceOf(creditAccount);
        if (amount <= diffInput.leftoverTokenIn) return false;

        unchecked {
            amount -= diffInput.leftoverTokenIn;
        }

        TokenInput memory input;
        input.tokenIn = diffInput.tokenIn;
        input.netTokenIn = amount;
        input.tokenMintSy = diffInput.tokenIn;

        LimitOrderData memory limit;

        _executeSwapSafeApprove(
            diffInput.tokenIn,
            abi.encodeCall(
                IPendleRouter.swapExactTokenForPt,
                (creditAccount, market, amount * minRateRAY / RAY, guessPtOut, input, limit)
            )
        ); // U:[PEND-4]

        useSafePrices = true;
    }

    /// @notice Swaps a specified amount of PT for token
    /// @param market Address of the market to swap in
    /// @param exactPtIn Amount of PT to swap
    /// @param output Output token params
    /// @notice `receiver` and `limit` are ignored, since the recipient is always the Credit Account,
    ///         and Gearbox does not use Pendle's limit orders
    function swapExactPtForToken(
        address,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output,
        LimitOrderData calldata
    )
        external
        creditFacadeOnly // U:[PEND-2]
        returns (bool useSafePrices)
    {
        (, address pt,) = IPendleMarket(market).readTokens();

        if (isPairAllowed[market][output.tokenOut][pt] == PendleStatus.NOT_ALLOWED) revert PairNotAllowedException(); // U:[PEND-5]

        address creditAccount = _creditAccount();

        LimitOrderData memory limit;

        TokenOutput memory output_m;

        {
            output_m.tokenOut = output.tokenOut;
            output_m.tokenRedeemSy = output.tokenOut;
            output_m.minTokenOut = output.minTokenOut;
        }

        _executeSwapSafeApprove(
            pt, abi.encodeCall(IPendleRouter.swapExactPtForToken, (creditAccount, market, exactPtIn, output_m, limit))
        ); // U:[PEND-5]

        useSafePrices = true;
    }

    /// @notice Swaps the entire balance of PT into input token, except the specified amount
    /// @param market Address of the market to swap in
    /// @param leftoverPt Amount of PT to leave on the Credit Account
    /// @param diffOutput Output token parameters
    function swapDiffPtForToken(address market, uint256 leftoverPt, TokenDiffOutput calldata diffOutput)
        external
        creditFacadeOnly // U:[PEND-2]
        returns (bool useSafePrices)
    {
        (, address pt,) = IPendleMarket(market).readTokens();

        if (isPairAllowed[market][diffOutput.tokenOut][pt] == PendleStatus.NOT_ALLOWED) {
            revert PairNotAllowedException(); // U:[PEND-6]
        }

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(pt).balanceOf(creditAccount);
        if (amount <= leftoverPt) return false;

        unchecked {
            amount -= leftoverPt;
        }

        TokenOutput memory output;
        output.tokenOut = diffOutput.tokenOut;
        output.minTokenOut = amount * diffOutput.minRateRAY / RAY;
        output.tokenRedeemSy = diffOutput.tokenOut;

        LimitOrderData memory limit;

        _executeSwapSafeApprove(
            pt, abi.encodeCall(IPendleRouter.swapExactPtForToken, (creditAccount, market, amount, output, limit))
        ); // U:[PEND-6]

        useSafePrices = true;
    }

    /// @notice Redeems a specified amount of PT tokens into underlying after expiry
    /// @param yt YT token associated to PT
    /// @param netPyIn Amount of PT token to redeem
    /// @param output Output token params
    /// @notice `receiver` is ignored, since the recipient is always the Credit Account
    /// @notice Before expiry PT redemption also spends a corresponding amount of YT. To avoid the CA interacting
    ///         with potentially non-collateral YT tokens, this function is only executable after expiry
    function redeemPyToToken(address, address yt, uint256 netPyIn, TokenOutput calldata output)
        external
        creditFacadeOnly // U:[PEND-2]
        returns (bool useSafePrices)
    {
        address pt = IYToken(yt).PT();

        if (
            IPToken(pt).YT() != yt || !isRedemptionAllowed[output.tokenOut][pt]
                || IYToken(yt).expiry() > block.timestamp
        ) {
            revert RedemptionNotAllowedException(); // U:[PEND-7]
        }

        address creditAccount = _creditAccount();

        TokenOutput memory output_m;

        {
            output_m.tokenOut = output.tokenOut;
            output_m.tokenRedeemSy = output.tokenOut;
            output_m.minTokenOut = output.minTokenOut;
        }

        _executeSwapSafeApprove(
            pt, abi.encodeCall(IPendleRouter.redeemPyToToken, (creditAccount, yt, netPyIn, output_m))
        ); // U:[PEND-7]

        useSafePrices = true;
    }

    /// @notice Redeems the entire balance of PT token into underlying after expiry, except the specified amount
    /// @param yt YT token associated to PT
    /// @param leftoverPt Amount of PT to keep on the account
    /// @param diffOutput Output token parameters
    /// @notice Before expiry PT redemption also spends a corresponding amount of YT. To avoid the CA interacting
    ///         with potentially non-collateral YT tokens, this function is only executable after expiry
    function redeemDiffPyToToken(address yt, uint256 leftoverPt, TokenDiffOutput calldata diffOutput)
        external
        creditFacadeOnly // U:[PEND-2]
        returns (bool useSafePrices)
    {
        address pt = IYToken(yt).PT();

        if (
            IPToken(pt).YT() != yt || !isRedemptionAllowed[diffOutput.tokenOut][pt]
                || IYToken(yt).expiry() > block.timestamp
        ) {
            revert RedemptionNotAllowedException(); // U:[PEND-8]
        }

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(pt).balanceOf(creditAccount);
        if (amount <= leftoverPt) return false;

        unchecked {
            amount -= leftoverPt;
        }

        TokenOutput memory output;
        output.tokenOut = diffOutput.tokenOut;
        output.minTokenOut = amount * diffOutput.minRateRAY / RAY;
        output.tokenRedeemSy = diffOutput.tokenOut;

        _executeSwapSafeApprove(pt, abi.encodeCall(IPendleRouter.redeemPyToToken, (creditAccount, yt, amount, output))); // U:[PEND-8]

        useSafePrices = true;
    }

    // ---- //
    // DATA //
    // ---- //

    /// @notice Return the list of all pairs currently allowed in the adapter
    function getAllowedPairs() public view returns (PendlePairStatus[] memory pairs) {
        bytes32[] memory allowedHashes = _allowedPairHashes.values();
        uint256 len = allowedHashes.length;

        pairs = new PendlePairStatus[](len);

        for (uint256 i = 0; i < len;) {
            pairs[i] = _hashToPendlePair[allowedHashes[i]];

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, getAllowedPairs());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets the allowed status of several (market, inputToken, pendleToken) tuples
    function setPairStatusBatch(PendlePairStatus[] calldata pairs)
        external
        override
        configuratorOnly // U:[PEND-9]
    {
        uint256 len = pairs.length;
        for (uint256 i; i < len; ++i) {
            isPairAllowed[pairs[i].market][pairs[i].inputToken][pairs[i].pendleToken] = pairs[i].status; // U:[PEND-9]
            (, address pt,) = IPendleMarket(pairs[i].market).readTokens();
            ptToMarket[pt] = pairs[i].market;
            bytes32 pairHash = keccak256(abi.encode(pairs[i].market, pairs[i].inputToken, pairs[i].pendleToken));
            if (pairs[i].status != PendleStatus.NOT_ALLOWED) {
                _allowedPairHashes.add(pairHash); // U:[PEND-9]
                isRedemptionAllowed[pairs[i].inputToken][pairs[i].pendleToken] = true; // U:[PEND-9]
                _getMaskOrRevert(pairs[i].inputToken);
                _getMaskOrRevert(pairs[i].pendleToken);
            } else {
                _allowedPairHashes.remove(pairHash); // U:[PEND-9]
                isRedemptionAllowed[pairs[i].inputToken][pairs[i].pendleToken] = false; // U:[PEND-9]
            }
            _hashToPendlePair[pairHash] = pairs[i]; // U:[PEND-9]

            emit SetPairStatus(pairs[i].market, pairs[i].inputToken, pairs[i].pendleToken, pairs[i].status); // U:[PEND-9]
        }
    }
}
