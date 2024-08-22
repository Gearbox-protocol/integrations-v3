// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

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

    AdapterType public constant override _gearboxAdapterType = AdapterType.PENDLE_ROUTER;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

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
    ///        * `tokenIn` - token to swap into PT
    ///        * `netTokenIn` - amount of tokens to swap
    ///        * `tokenMintSy` - token used to mint SY. Since the adapter does not use PendleRouter's external routing features,
    ///                            this is always enforced to be equal to `tokenIn`
    ///        * `pendleSwap` - address of the swap aggregator. Since the adapter does not use PendleRouter's external routing features,
    ///                         this is always enforced to be `address(0)`.
    ///        * `swapData` - off-chain data for external routing. Since the adapter does not use PendleRouter's external routing features,
    ///                            this is always enforced to be an empty struct
    /// @notice `receiver` and `limit` are ignored, since the recipient is always the Credit Account,
    ///         and Gearbox does not use Pendle's limit orders
    function swapExactTokenForPt(
        address,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input,
        LimitOrderData calldata
    ) external creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        (, address pt,) = IPendleMarket(market).readTokens();

        if (isPairAllowed[market][input.tokenIn][pt] != PendleStatus.ALLOWED) revert PairNotAllowedException();

        address creditAccount = _creditAccount();

        LimitOrderData memory limit;

        TokenInput memory input_m;

        {
            input_m.tokenIn = input.tokenIn;
            input_m.netTokenIn = input.netTokenIn;
            input_m.tokenMintSy = input.tokenIn;
        }

        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            input_m.tokenIn,
            pt,
            abi.encodeCall(
                IPendleRouter.swapExactTokenForPt, (creditAccount, market, minPtOut, guessPtOut, input_m, limit)
            ),
            false
        );
    }

    /// @notice Swaps the entire balance of input token into PT, except the specified amount
    /// @param market Address of the market to swap in
    /// @param minRateRAY Minimal exchange rate of input to PT, in 1e27 format
    /// @param guessPtOut Search boundaries to save gas on PT amount calculation
    /// @param diffInput Input token parameters
    ///        * `tokenIn` - token to swap into PT
    ///        * `leftoverTokenIn` - amount of input token to leave on the account
    function swapDiffTokenForPt(
        address market,
        uint256 minRateRAY,
        ApproxParams calldata guessPtOut,
        TokenDiffInput calldata diffInput
    ) external creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        (, address pt,) = IPendleMarket(market).readTokens();

        if (isPairAllowed[market][diffInput.tokenIn][pt] != PendleStatus.ALLOWED) revert PairNotAllowedException();

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(diffInput.tokenIn).balanceOf(creditAccount);
        if (amount <= diffInput.leftoverTokenIn) return (0, 0);

        unchecked {
            amount -= diffInput.leftoverTokenIn;
        }

        TokenInput memory input;
        input.tokenIn = diffInput.tokenIn;
        input.netTokenIn = amount;
        input.tokenMintSy = diffInput.tokenIn;

        LimitOrderData memory limit;

        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            diffInput.tokenIn,
            pt,
            abi.encodeCall(
                IPendleRouter.swapExactTokenForPt,
                (creditAccount, market, amount * minRateRAY / RAY, guessPtOut, input, limit)
            ),
            diffInput.leftoverTokenIn <= 1
        );
    }

    /// @notice Swaps a specified amount of PT for token
    /// @param market Address of the market to swap in
    /// @param exactPtIn Amount of PT to swap
    /// @param output Output token params:
    ///        * `tokenOut` - token to swap PT into
    ///        * `minTokenOut` - the minimal amount of token to receive
    ///        * `tokenRedeemSy` - token received after redeeming SY. Since the adapter does not use PendleRouter's external routing features,
    ///                            this is always enforced to be equal to `tokenOut`
    ///        * `pendleSwap` - address of the swap aggregator. Since the adapter does not use PendleRouter's external routing features,
    ///                         this is always enforced to be `address(0)`.
    ///        * `swapData` - off-chain data for external routing. Since the adapter does not use PendleRouter's external routing features,
    ///                            this is always enforced to be an empty struct
    /// @notice `receiver` and `limit` are ignored, since the recipient is always the Credit Account,
    ///         and Gearbox does not use Pendle's limit orders
    function swapExactPtForToken(
        address,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output,
        LimitOrderData calldata
    ) external creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        (, address pt,) = IPendleMarket(market).readTokens();

        if (isPairAllowed[market][output.tokenOut][pt] == PendleStatus.NOT_ALLOWED) revert PairNotAllowedException();

        address creditAccount = _creditAccount();

        LimitOrderData memory limit;

        TokenOutput memory output_m;

        {
            output_m.tokenOut = output.tokenOut;
            output_m.tokenRedeemSy = output.tokenOut;
            output_m.minTokenOut = output.minTokenOut;
        }

        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            pt,
            output_m.tokenOut,
            abi.encodeCall(IPendleRouter.swapExactPtForToken, (creditAccount, market, exactPtIn, output_m, limit)),
            false
        );
    }

    /// @notice Swaps the entire balance of PT into input token, except the specified amount
    /// @param market Address of the market to swap in
    /// @param leftoverPt Amount of PT to leave on the Credit Account
    /// @param diffOutput Output token parameters:
    ///        * `tokenOut` - token to swap PT into
    ///        * `minRateRAY` - minimal exchange rate of PT into the output token
    function swapDiffPtForToken(address market, uint256 leftoverPt, TokenDiffOutput calldata diffOutput)
        external
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (, address pt,) = IPendleMarket(market).readTokens();

        if (isPairAllowed[market][diffOutput.tokenOut][pt] == PendleStatus.NOT_ALLOWED) {
            revert PairNotAllowedException();
        }

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(pt).balanceOf(creditAccount);
        if (amount <= leftoverPt) return (0, 0);

        unchecked {
            amount -= leftoverPt;
        }

        TokenOutput memory output;
        output.tokenOut = diffOutput.tokenOut;
        output.minTokenOut = amount * diffOutput.minRateRAY / RAY;
        output.tokenRedeemSy = diffOutput.tokenOut;

        LimitOrderData memory limit;

        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            pt,
            diffOutput.tokenOut,
            abi.encodeCall(IPendleRouter.swapExactPtForToken, (creditAccount, market, amount, output, limit)),
            leftoverPt <= 1
        );
    }

    /// @notice Redeems a specified amount of PT tokens into underlying after expiry
    /// @param yt YT token associated to PT
    /// @param netPyIn Amount of PT token to redeem
    /// @param output Output token params:
    ///        * `tokenOut` - token to swap PT into
    ///        * `minTokenOut` - the minimal amount of token to receive
    ///        * `tokenRedeemSy` - token received after redeeming SY. Since the adapter does not use PendleRouter's external routing features,
    ///                            this is always enforced to be equal to `tokenOut`
    ///        * `pendleSwap` - address of the swap aggregator. Since the adapter does not use PendleRouter's external routing features,
    ///                         this is always enforced to be `address(0)`.
    ///        * `swapData` - off-chain data for external routing. Since the adapter does not use PendleRouter's external routing features,
    ///                            this is always enforced to be an empty struct
    /// @notice `receiver` is ignored, since the recipient is always the Credit Account
    /// @notice Before expiry PT redemption also spends a corresponding amount of YT. To avoid the CA interacting
    ///         with potentially non-collateral YT tokens, this function is only executable after expiry
    function redeemPyToToken(address, address yt, uint256 netPyIn, TokenOutput calldata output)
        external
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address pt = IYToken(yt).PT();

        if (
            IPToken(pt).YT() != yt || !isRedemptionAllowed[output.tokenOut][pt]
                || IYToken(yt).expiry() > block.timestamp
        ) {
            revert RedemptionNotAllowedException();
        }

        address creditAccount = _creditAccount();

        TokenOutput memory output_m;

        {
            output_m.tokenOut = output.tokenOut;
            output_m.tokenRedeemSy = output.tokenOut;
            output_m.minTokenOut = output.minTokenOut;
        }

        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            pt,
            output_m.tokenOut,
            abi.encodeCall(IPendleRouter.redeemPyToToken, (creditAccount, yt, netPyIn, output_m)),
            false
        );
    }
    /// @notice Redeems the entire balance of PT token into underlying after expiry, except the specified amount
    /// @param yt YT token associated to PT
    /// @param leftoverPt Amount of PT to keep on the account
    /// @param diffOutput Output token parameters:
    ///        * `tokenOut` - token to swap PT into
    ///        * `minRateRAY` - minimal exchange rate of PT into the output token
    /// @notice Before expiry PT redemption also spends a corresponding amount of YT. To avoid the CA interacting
    ///         with potentially non-collateral YT tokens, this function is only executable after expiry

    function redeemDiffPyToToken(address yt, uint256 leftoverPt, TokenDiffOutput calldata diffOutput)
        external
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address pt = IYToken(yt).PT();

        if (
            IPToken(pt).YT() != yt || !isRedemptionAllowed[diffOutput.tokenOut][pt]
                || IYToken(yt).expiry() > block.timestamp
        ) {
            revert RedemptionNotAllowedException();
        }

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(pt).balanceOf(creditAccount);
        if (amount <= leftoverPt) return (0, 0);

        unchecked {
            amount -= leftoverPt;
        }

        TokenOutput memory output;
        output.tokenOut = diffOutput.tokenOut;
        output.minTokenOut = amount * diffOutput.minRateRAY / RAY;
        output.tokenRedeemSy = diffOutput.tokenOut;

        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            pt,
            diffOutput.tokenOut,
            abi.encodeCall(IPendleRouter.redeemPyToToken, (creditAccount, yt, amount, output)),
            leftoverPt <= 1
        );
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Return the list of all markets that were ever allowed in this adapter
    function getAllowedPairs() external view override returns (PendlePairStatus[] memory pairs) {
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

    /// @notice Sets the allowed status of several (market, inputToken, pendleToken) tuples
    function setPairStatusBatch(PendlePairStatus[] calldata pairs) external override configuratorOnly {
        uint256 len = pairs.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                isPairAllowed[pairs[i].market][pairs[i].inputToken][pairs[i].pendleToken] = pairs[i].status;
                (, address pt,) = IPendleMarket(pairs[i].market).readTokens();
                ptToMarket[pt] = pairs[i].market;
                bytes32 pairHash = keccak256(abi.encode(pairs[i].market, pairs[i].inputToken, pairs[i].pendleToken));
                if (pairs[i].status != PendleStatus.NOT_ALLOWED) {
                    _allowedPairHashes.add(pairHash);
                    isRedemptionAllowed[pairs[i].inputToken][pairs[i].pendleToken] = true;
                } else {
                    _allowedPairHashes.remove(pairHash);
                    isRedemptionAllowed[pairs[i].inputToken][pairs[i].pendleToken] = false;
                }
                _hashToPendlePair[pairHash] = pairs[i];

                emit SetPairStatus(pairs[i].market, pairs[i].inputToken, pairs[i].pendleToken, pairs[i].status);
            }
        }
    }
}
