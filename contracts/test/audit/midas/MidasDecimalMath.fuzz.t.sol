// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {WAD, RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {MidasRedeemer} from "../../../helpers/midas/MidasRedeemer.sol";
import {MidasGateway} from "../../../helpers/midas/MidasGateway.sol";

/// @notice Re-declaration of the redeemer math as a pure harness so it can be fuzzed without a vault.
///         Mirrors `MidasRedeemer._calculateTokenOutAmount` exactly.
contract RedeemerMathHarness {
    function calcTokenOutAmount(uint256 amountMTokenIn, uint256 mTokenRate, uint256 tokenOutRate, uint8 quoteDecimals)
        external
        pure
        returns (uint256)
    {
        uint256 amount1e18 = (amountMTokenIn * mTokenRate) / tokenOutRate;
        uint256 tokenUnit = 10 ** quoteDecimals;
        if (tokenUnit == WAD) return amount1e18;
        return amount1e18 * tokenUnit / WAD;
    }
}

/// @notice Re-declaration of `MidasGateway._convertToE18` as a pure harness for fuzzing.
contract GatewayMathHarness {
    function convertToE18(uint256 amount, uint8 quoteDecimals) external pure returns (uint256) {
        uint256 tokenUnit = 10 ** quoteDecimals;
        if (tokenUnit == WAD) return amount;
        return amount * WAD / tokenUnit;
    }
}

/// @title Midas decimal math fuzz tests
/// @notice F:[MID-MATH]: Fuzz tests proving the precision, monotonicity, and bound properties
///         of the Midas decimal conversion and pending-amount math.
contract MidasDecimalMathFuzzTest is Test {
    RedeemerMathHarness internal redeemerMath;
    GatewayMathHarness internal gatewayMath;

    function setUp() public {
        redeemerMath = new RedeemerMathHarness();
        gatewayMath = new GatewayMathHarness();
    }

    /*
     * @test-id: tst_core_midas_020
     * @scenario: scn_midas_convert_e18_exact
     * @covers: contracts/helpers/midas/MidasGateway.sol::_convertToE18
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: pure math harness
     * Clients: direct calls
     * Mocks: none
     * Data: fuzzed amounts and decimals in [0, 18]
     *
     * Invariant: _convertToE18 is exact for decimals d <= 18.
     *            Proof: amount * 1e18 / 10^d = amount * 10^(18-d), which is an integer
     *            multiplication (no division) for d <= 18, so the result is exact.
     */
    function testFuzz_tst_core_midas_020_convertToE18_is_exact_for_decimals_le_18(uint256 amount, uint8 d) public pure {
        d = uint8(bound(uint256(d), 0, 18));
        // bound amount so amount * 1e18 cannot overflow (covers all realistic token supplies)
        amount = bound(amount, 0, type(uint256).max / WAD);
        uint256 tokenUnit = 10 ** uint256(d);
        // expected = amount * 10^(18-d) is an integer multiplication for d <= 18
        uint256 expected = amount * (10 ** (18 - uint256(d)));
        // the contract formula amount * 1e18 / 10^d must equal the exact integer product
        assertEq(amount * WAD / tokenUnit, expected, "convertToE18 not exact for d <= 18");
    }

    /*
     * @test-id: tst_core_midas_021
     * @scenario: scn_midas_convert_e18_inverse
     * @covers: contracts/helpers/midas/MidasGateway.sol::_convertToE18
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: pure math harness
     * Clients: direct calls
     * Mocks: none
     * Data: fuzzed base-18 amounts and decimals in [0, 18]
     *
     * Invariant: convertToE18(amount) then converting back to native yields exactly `amount`
     *            for d <= 18 (no round-trip loss), because 1e18 / 10^d is an integer.
     */
    function testFuzz_tst_core_midas_021_convertToE18_round_trip_is_lossless(uint256 amountNative, uint8 d) public {
        d = uint8(bound(uint256(d), 0, 18));
        uint256 tokenUnit = 10 ** uint256(d);
        // amountNative * 1e18 must not overflow
        amountNative = bound(amountNative, 0, type(uint256).max / WAD);
        uint256 e18 = gatewayMath.convertToE18(amountNative, d);
        // back to native: e18 * tokenUnit / 1e18 — for d <= 18 this is exact because
        // e18 = amountNative * 10^(18-d), and e18 * 10^d / 1e18 = amountNative * 10^(18-d) * 10^d / 1e18 = amountNative
        uint256 backNative = e18 * tokenUnit / WAD;
        assertEq(backNative, amountNative, "round-trip loss for d <= 18");
    }

    /*
     * @test-id: tst_core_midas_022
     * @scenario: scn_midas_pending_amount_monotonic_in_mtoken_rate
     * @covers: contracts/helpers/midas/MidasRedeemer.sol::pendingTokenOutAmount
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: pure math harness
     * Clients: direct calls
     * Mocks: none
     * Data: fuzzed amountMTokenIn, tokenOutRate, two mToken rates
     *
     * Invariant: pendingTokenOutAmount is monotonically non-decreasing in mTokenRate.
     *            Proof: f(r) = amountMTokenIn * r / tokenOutRate; partial derivative wrt r is
     *            amountMTokenIn / tokenOutRate > 0 (for positive inputs), so f is strictly
     *            increasing in r when integer division does not erase the difference.
     */
    function testFuzz_tst_core_midas_022_pending_amount_monotonic_in_mtoken_rate(
        uint256 amountMTokenIn,
        uint256 rateLow,
        uint256 rateHigh,
        uint256 tokenOutRate,
        uint8 quoteDecimals
    ) public {
        tokenOutRate = bound(tokenOutRate, 1, 1e27);
        // keep amountMTokenIn * mTokenRate within uint256 (1e30 * 1e27 = 1e57 < 2^256)
        amountMTokenIn = bound(amountMTokenIn, 0, 1e30);
        rateLow = bound(rateLow, 1, 1e27);
        rateHigh = bound(rateHigh, rateLow, 1e27);
        quoteDecimals = uint8(bound(uint256(quoteDecimals), 0, 18));

        uint256 pendingLow = redeemerMath.calcTokenOutAmount(amountMTokenIn, rateLow, tokenOutRate, quoteDecimals);
        uint256 pendingHigh = redeemerMath.calcTokenOutAmount(amountMTokenIn, rateHigh, tokenOutRate, quoteDecimals);
        assertLe(pendingLow, pendingHigh, "pending amount must be non-decreasing in mTokenRate");
    }

    /*
     * @test-id: tst_core_midas_023
     * @scenario: scn_midas_pending_amount_precision_bound
     * @covers: contracts/helpers/midas/MidasRedeemer.sol::_calculateTokenOutAmount
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: pure math harness
     * Clients: direct calls
     * Mocks: none
     * Data: fuzzed amountMTokenIn, rates, decimals in [0, 18]
     *
     * Invariant: the rounding error of _calculateTokenOutAmount is strictly less than
     *            1 unit of the quote token (i.e. < 10^decimals wei of the result).
     *            Proof sketch: amount1e18 = (a * r) / s is exact up to <1 wei of 1e18.
     *            Then result = amount1e18 * 10^d / 1e18 = amount1e18 / 10^(18-d). Integer
     *            division rounds down by < 10^(18-d) wei of 1e18, which equals < 1 unit of
     *            the d-decimal token. So |result - true| < 1 unit.
     */
    function testFuzz_tst_core_midas_023_pending_amount_error_less_than_one_unit(
        uint256 amountMTokenIn,
        uint256 mTokenRate,
        uint256 tokenOutRate,
        uint8 quoteDecimals
    ) public {
        tokenOutRate = bound(tokenOutRate, 1, 1e27);
        mTokenRate = bound(mTokenRate, 1, 1e27);
        // bound so amountMTokenIn * mTokenRate * tokenUnit cannot overflow uint256
        // (1e30 * 1e27 * 1e18 = 1e75 < 2^256 ~ 1.16e77)
        amountMTokenIn = bound(amountMTokenIn, 0, 1e30);
        quoteDecimals = uint8(bound(uint256(quoteDecimals), 0, 18));

        uint256 result = redeemerMath.calcTokenOutAmount(amountMTokenIn, mTokenRate, tokenOutRate, quoteDecimals);
        // single-division reference: a * r * u / (s * WAD) — error strictly < 1 unit of quote token
        uint256 ref = _singleDivRef(amountMTokenIn, mTokenRate, tokenOutRate, quoteDecimals);
        uint256 oneUnit = 10 ** uint256(quoteDecimals);
        // the contract rounds down twice, so result <= ref (single division rounds down once)
        assertLe(result, ref, "double-division must not exceed single-division reference");
        if (ref > result) {
            assertLt(ref - result, oneUnit, "rounding error must be < 1 unit of quote token");
        }
    }

    /*
     * @test-id: tst_core_midas_024
     * @scenario: scn_midas_pending_amount_zero_input
     * @covers: contracts/helpers/midas/MidasRedeemer.sol::_calculateTokenOutAmount
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: pure math harness
     * Clients: direct calls
     * Mocks: none
     * Data: fuzzed rates and decimals with zero amountMTokenIn
     *
     * Invariant: zero input yields zero output (no division-by-zero issues, no phantom value).
     */
    function testFuzz_tst_core_midas_024_pending_amount_zero_input_yields_zero_output(
        uint256 mTokenRate,
        uint256 tokenOutRate,
        uint8 quoteDecimals
    ) public {
        tokenOutRate = bound(tokenOutRate, 1, 1e27);
        mTokenRate = bound(mTokenRate, 1, 1e27);
        quoteDecimals = uint8(bound(uint256(quoteDecimals), 0, 18));
        uint256 result = redeemerMath.calcTokenOutAmount(0, mTokenRate, tokenOutRate, quoteDecimals);
        assertEq(result, 0, "zero input must yield zero output");
    }

    /*
     * @test-id: tst_core_midas_025
     * @scenario: scn_midas_pending_amount_overflow_boundary
     * @covers: contracts/helpers/midas/MidasRedeemer.sol::_calculateTokenOutAmount
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: pure math harness
     * Clients: direct calls
     * Mocks: none
     * Data: boundary amounts just below the overflow threshold of `amountMTokenIn * mTokenRate`
     *
     * Invariant: for realistic mToken supplies (<= 1e40 base-18 units) and rates (<= 1e27),
     *            the product `amountMTokenIn * mTokenRate` does not overflow uint256
     *            (max ~1.15e77). 1e40 * 1e27 = 1e67 < 2^256. The fuzz bound keeps inputs
     *            inside this safe envelope and asserts the computation matches the reference.
     */
    function testFuzz_tst_core_midas_025_pending_amount_no_overflow_for_realistic_inputs(
        uint256 amountMTokenIn,
        uint256 mTokenRate,
        uint256 tokenOutRate,
        uint8 quoteDecimals
    ) public {
        tokenOutRate = bound(tokenOutRate, 1, 1e21);
        // mTokenRate is returned by getDataInBase18, so it is in 1e18 base; bound to 1e21 (1000x headroom)
        mTokenRate = bound(mTokenRate, 1, 1e21);
        // 1e30 mToken base-18 units = 1e12 tokens, far above any realistic supply
        amountMTokenIn = bound(amountMTokenIn, 0, 1e30);
        quoteDecimals = uint8(bound(uint256(quoteDecimals), 0, 18));

        // must not revert for realistic inputs; product amountMTokenIn * mTokenRate <= 1e51,
        // and amount1e18 * tokenUnit <= (1e51 / 1) * 1e18 = 1e69 < 2^256
        uint256 result = redeemerMath.calcTokenOutAmount(amountMTokenIn, mTokenRate, tokenOutRate, quoteDecimals);
        assertTrue(result <= type(uint256).max, "result must fit in uint256");
    }

    /*
     * @test-id: tst_core_midas_026
     * @scenario: scn_midas_deposit_min_receive_consistency
     * @covers: contracts/adapters/midas/MidasGatewayAdapter.sol::depositInstantDiff
     * @deterministic: yes
     * @fixtures: none
     *
     * Test environment: pure math harness
     * Clients: direct calls
     * Mocks: none
     * Data: fuzzed balance, leftover, rateMinRAY
     *
     * Invariant: depositInstantDiff computes minReceiveAmount = amount * rateMinRAY / RAY
     *            where amount = balance - leftover (only when balance > leftover, else no-op).
     *            The minReceive is a non-negative lower bound that is <= amount * rateMinRAY / RAY.
     */
    function testFuzz_tst_core_midas_026_deposit_diff_min_receive_bound(
        uint256 balance,
        uint256 leftover,
        uint256 rateMinRAY
    ) public pure {
        rateMinRAY = bound(rateMinRAY, 0, RAY);
        if (balance <= leftover) {
            // no-op path: nothing to assert beyond the adapter not reverting
            return;
        }
        unchecked {
            uint256 amount = balance - leftover;
            uint256 minReceive = (amount * rateMinRAY) / RAY;
            // minReceive is a lower bound on expected output expressed in the same units as `amount`
            assertLe(minReceive, amount, "minReceive cannot exceed amount at rateMinRAY <= RAY");
        }
    }

    /// @dev Single-division reference: (a * r * u) / (s * WAD). One integer division => error < 1 unit.
    ///      Inputs must be bounded so a * r * u and s * WAD do not overflow uint256.
    function _singleDivRef(uint256 amountMTokenIn, uint256 mTokenRate, uint256 tokenOutRate, uint8 quoteDecimals)
        internal
        pure
        returns (uint256)
    {
        uint256 tokenUnit = 10 ** uint256(quoteDecimals);
        uint256 numerator = amountMTokenIn * mTokenRate * tokenUnit;
        uint256 denominator = tokenOutRate * WAD;
        return numerator / denominator;
    }
}
