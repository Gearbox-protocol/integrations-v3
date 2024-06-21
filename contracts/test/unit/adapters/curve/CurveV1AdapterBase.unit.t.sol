// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {
    IncorrectParameterException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {PoolMock, PoolType} from "../../../mocks/integrations/curve/PoolMock.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {CurveV1AdapterBaseHarness} from "./CurveV1AdapterBase.harness.sol";

/// @title Curve v1 adapter base unit test
/// @notice U:[CRVB]: Unit tests for Curve pool adapter base
contract CurveV1AdapterBaseUnitTest is AdapterUnitTestHelper {
    CurveV1AdapterBaseHarness adapter;
    PoolMock basePool;
    PoolMock curvePool;

    address token0;
    address token1;
    address underlying0;
    address underlying1;
    address lpToken;

    uint256 token0Mask;
    uint256 token1Mask;
    uint256 underlying0Mask;
    uint256 underlying1Mask;
    uint256 lpTokenMask;

    // ----- //
    // SETUP //
    // ----- //

    modifier onlyStablePools() {
        _setupPoolAndAdapter(PoolType.Stable);
        _;
    }

    modifier onlyCryptoPools() {
        _setupPoolAndAdapter(PoolType.Crypto);
        _;
    }

    modifier bothStableAndCryptoPools() {
        uint256 snapshot = vm.snapshot();
        _setupPoolAndAdapter(PoolType.Stable);
        _;
        vm.revertTo(snapshot);
        _setupPoolAndAdapter(PoolType.Crypto);
        _;
    }

    function setUp() public {
        _setUp();

        (token0, token0Mask) = (tokens[0], 1);
        (token1, token1Mask) = (tokens[1], 2);
        (underlying0, underlying0Mask) = (tokens[2], 4);
        (underlying1, underlying1Mask) = (tokens[3], 8);
        (lpToken, lpTokenMask) = (tokens[4], 16);
    }

    function _setupPoolAndAdapter(PoolType poolType) internal {
        address[] memory baseCoins = new address[](2);
        baseCoins[0] = underlying0;
        baseCoins[1] = underlying1;
        basePool = new PoolMock(poolType, baseCoins, new address[](0));

        address[] memory coins = new address[](2);
        coins[0] = token0;
        coins[1] = token1;
        curvePool = new PoolMock(poolType, coins, new address[](0));

        adapter =
            new CurveV1AdapterBaseHarness(address(creditManager), address(curvePool), lpToken, address(basePool), 2);

        assertEq(adapter.use256(), poolType == PoolType.Crypto, "Incorrect use256");
    }

    // ------- //
    // GENERAL //
    // ------- //

    /// @notice U:[CRVB-1]: Constructor works as expected
    function test_U_CRVB_01_constructor_works_as_expected() public {
        curvePool = new PoolMock(PoolType.Stable, new address[](0), new address[](0));

        // reverts on zero LP token
        vm.expectRevert(ZeroAddressException.selector);
        new CurveV1AdapterBaseHarness(address(creditManager), address(curvePool), address(0), address(0), 2);

        // reverts when pool has fewer coins than needed
        vm.expectRevert(IncorrectParameterException.selector);
        new CurveV1AdapterBaseHarness(address(creditManager), address(curvePool), lpToken, address(0), 2);

        // plain pool
        address[] memory coins = new address[](2);
        coins[0] = token0;
        coins[1] = token1;
        curvePool = new PoolMock(PoolType.Stable, coins, new address[](0));

        _readsTokenMask(token0);
        _readsTokenMask(token1);
        _readsTokenMask(lpToken);
        adapter = new CurveV1AdapterBaseHarness(address(creditManager), address(curvePool), lpToken, address(0), 2);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(curvePool), "Incorrect targetContract");

        assertEq(adapter.token(), lpToken, "Incorrect token");
        assertEq(adapter.lp_token(), lpToken, "Incorrect token");
        assertEq(adapter.lpTokenMask(), lpTokenMask, "Incorrect lpTokenMask");
        assertEq(adapter.metapoolBase(), address(0), "Incorrect metapoolBase");
        assertEq(adapter.nCoins(), 2, "Incorrect nCoins");
        assertEq(adapter.token0(), token0, "Incorrect token0");
        assertEq(adapter.token1(), token1, "Incorrect token1");
        assertEq(adapter.token0Mask(), token0Mask, "Incorrect token0Mask");
        assertEq(adapter.token1Mask(), token1Mask, "Incorrect token1Mask");

        // metapool
        address[] memory underlyings = new address[](2);
        underlyings[0] = underlying0;
        underlyings[1] = underlying1;
        basePool = new PoolMock(PoolType.Stable, underlyings, new address[](0));

        _readsTokenMask(token0);
        _readsTokenMask(token1);
        _readsTokenMask(underlying0);
        _readsTokenMask(underlying1);
        _readsTokenMask(lpToken);
        adapter =
            new CurveV1AdapterBaseHarness(address(creditManager), address(curvePool), lpToken, address(basePool), 2);

        assertEq(adapter.metapoolBase(), address(basePool), "Incorrect metapoolBase");
        assertEq(adapter.underlying0(), token0, "Incorrect underlying0");
        assertEq(adapter.underlying1(), underlying0, "Incorrect underlying1");
        assertEq(adapter.underlying2(), underlying1, "Incorrect underlying2");
        assertEq(adapter.underlying0Mask(), token0Mask, "Incorrect underlying0Mask");
        assertEq(adapter.underlying1Mask(), underlying0Mask, "Incorrect underlying1Mask");
        assertEq(adapter.underlying2Mask(), underlying1Mask, "Incorrect underlying2Mask");

        // lending pool
        curvePool = new PoolMock(PoolType.Stable, coins, underlyings);

        _readsTokenMask(token0);
        _readsTokenMask(token1);
        _readsTokenMask(underlying0);
        _readsTokenMask(underlying1);
        _readsTokenMask(lpToken);
        adapter = new CurveV1AdapterBaseHarness(address(creditManager), address(curvePool), lpToken, address(0), 2);
        assertEq(adapter.metapoolBase(), address(0), "Incorrect metapoolBase");
        assertEq(adapter.underlying0(), underlying0, "Incorrect underlying0");
        assertEq(adapter.underlying1(), underlying1, "Incorrect underlying1");
        assertEq(adapter.underlying0Mask(), underlying0Mask, "Incorrect underlying0Mask");
        assertEq(adapter.underlying1Mask(), underlying1Mask, "Incorrect underlying1Mask");
    }

    /// @notice U:[CRVB-2]: Wrapper functions revert on wrong caller
    function test_U_CRVB_02_wrapper_functions_revert_on_wrong_caller() public bothStableAndCryptoPools {
        _revertsOnNonFacadeCaller();
        adapter.exchange(uint256(0), uint256(0), 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.exchange(int128(0), int128(0), 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.exchange_diff(uint256(0), uint256(0), 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.exchange_underlying(uint256(0), uint256(0), 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.exchange_underlying(int128(0), int128(0), 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.exchange_diff_underlying(uint256(0), uint256(0), 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.add_liquidity_one_coin(0, 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.add_diff_liquidity_one_coin(0, 0, 0);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity_one_coin(0, uint256(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity_one_coin(0, int128(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.remove_diff_liquidity_one_coin(0, uint256(0), 0);
    }

    // -------- //
    // EXCHANGE //
    // -------- //

    /// @notice U:[CRVB-3]: `exchange` works as expected
    function test_U_CRVB_03_exchange_works_as_expected() public bothStableAndCryptoPools {
        for (uint256 i; i < 2; ++i) {
            bool use256 = i == 2;

            _executesSwap({
                tokenIn: token0,
                tokenOut: token1,
                callData: abi.encodeWithSignature(
                    curvePool.isCrypto()
                        ? "exchange(uint256,uint256,uint256,uint256)"
                        : "exchange(int128,int128,uint256,uint256)",
                    0,
                    1,
                    1000,
                    500
                    ),
                requiresApproval: true,
                validatesTokens: false
            });

            vm.prank(creditFacade);
            (uint256 tokensToEnable, uint256 tokensToDisable) = use256
                ? adapter.exchange(uint256(0), uint256(1), 1000, 500)
                : adapter.exchange(int128(0), int128(1), 1000, 500);

            assertEq(tokensToEnable, token1Mask, "Incorrect tokensToEnable");
            assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
        }
    }

    /// @notice U:[CRVB-4]: `exchange_diff` works as expected
    function test_U_CRVB_04_exchange_diff_works_as_expected() public bothStableAndCryptoPools diffTestCases {
        deal({token: token0, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: token0,
            tokenOut: token1,
            callData: abi.encodeWithSignature(
                curvePool.isCrypto()
                    ? "exchange(uint256,uint256,uint256,uint256)"
                    : "exchange(int128,int128,uint256,uint256)",
                0,
                1,
                diffInputAmount,
                diffInputAmount / 2
                ),
            requiresApproval: true,
            validatesTokens: false
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.exchange_diff(uint256(0), uint256(1), diffLeftoverAmount, 0.5e27);

        assertEq(tokensToEnable, token1Mask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? token0Mask : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CRVB-5]: `exchange_underlying` works as expected
    function test_U_CRVB_05_exchange_underlying_works_as_expected() public bothStableAndCryptoPools {
        for (uint256 i; i < 2; ++i) {
            bool use256 = i == 2;

            _executesSwap({
                tokenIn: token0,
                tokenOut: underlying0,
                callData: abi.encodeWithSignature(
                    curvePool.isCrypto()
                        ? "exchange_underlying(uint256,uint256,uint256,uint256)"
                        : "exchange_underlying(int128,int128,uint256,uint256)",
                    0,
                    1,
                    1000,
                    500
                    ),
                requiresApproval: true,
                validatesTokens: false
            });

            vm.prank(creditFacade);
            (uint256 tokensToEnable, uint256 tokensToDisable) = use256
                ? adapter.exchange_underlying(uint256(0), uint256(1), 1000, 500)
                : adapter.exchange_underlying(int128(0), int128(1), 1000, 500);

            assertEq(tokensToEnable, underlying0Mask, "Incorrect tokensToEnable");
            assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
        }
    }

    /// @notice U:[CRVB-6]: `exchange_diff_underlying` works as expected
    function test_U_CRVB_06_exchange_diff_underlying_works_as_expected()
        public
        bothStableAndCryptoPools
        diffTestCases
    {
        deal({token: token0, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: token0,
            tokenOut: underlying0,
            callData: abi.encodeWithSignature(
                curvePool.isCrypto()
                    ? "exchange_underlying(uint256,uint256,uint256,uint256)"
                    : "exchange_underlying(int128,int128,uint256,uint256)",
                0,
                1,
                diffInputAmount,
                diffInputAmount / 2
                ),
            requiresApproval: true,
            validatesTokens: false
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.exchange_diff_underlying(uint256(0), uint256(1), diffLeftoverAmount, 0.5e27);

        assertEq(tokensToEnable, underlying0Mask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? token0Mask : 0, "Incorrect tokensToDisable");
    }

    // ------------- //
    // ADD LIQUIDITY //
    // ------------- //

    /// @notice U:[CRVB-7]: `add_liquidity_one_coin` works as expected
    function test_U_CRVB_07_add_liquidity_one_coin_works_as_expected() public onlyStablePools {
        _executesSwap({
            tokenIn: token0,
            tokenOut: lpToken,
            callData: abi.encodeWithSignature("add_liquidity(uint256[2],uint256)", 1000, 0, 500),
            requiresApproval: true,
            validatesTokens: false
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.add_liquidity_one_coin(1000, 0, 500);

        assertEq(tokensToEnable, lpTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CRVB-8]: `add_diff_liquidity_one_coin` works as expected
    function test_U_CRVB_08_add_diff_liquidity_one_coin_works_as_expected() public onlyStablePools diffTestCases {
        deal({token: token0, to: creditAccount, give: diffMintedAmount});

        _executesSwap({
            tokenIn: token0,
            tokenOut: lpToken,
            callData: abi.encodeWithSignature("add_liquidity(uint256[2],uint256)", diffInputAmount, 0, diffInputAmount / 2),
            requiresApproval: true,
            validatesTokens: false
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.add_diff_liquidity_one_coin(diffLeftoverAmount, 0, 0.5e27);

        assertEq(tokensToEnable, lpTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? token0Mask : 0, "Incorrect tokensToDisable");
    }

    // ---------------- //
    // REMOVE LIQUIDITY //
    // ---------------- //

    /// @notice U:[CRVB-9]: `remove_liquidity_one_coin` works as expected
    function test_U_CRVB_09_remove_liquidity_one_coin_works_as_expected() public bothStableAndCryptoPools {
        for (uint256 i; i < 2; ++i) {
            bool use256 = i == 1;

            _executesSwap({
                tokenIn: lpToken,
                tokenOut: token0,
                callData: abi.encodeWithSignature(
                    curvePool.isCrypto()
                        ? "remove_liquidity_one_coin(uint256,uint256,uint256)"
                        : "remove_liquidity_one_coin(uint256,int128,uint256)",
                    1000,
                    0,
                    500
                    ),
                requiresApproval: false,
                validatesTokens: false
            });

            vm.prank(creditFacade);
            (uint256 tokensToEnable, uint256 tokensToDisable) = use256
                ? adapter.remove_liquidity_one_coin(1000, uint256(0), 500)
                : adapter.remove_liquidity_one_coin(1000, int128(0), 500);

            assertEq(tokensToEnable, token0Mask, "Incorrect tokensToEnable");
            assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
        }
    }

    /// @notice U:[CRVB-10]: `remove_diff_liquidity_one_coin` works as expected
    function test_U_CRVB_10_remove_diff_liquidity_one_coin_works_as_expected()
        public
        bothStableAndCryptoPools
        diffTestCases
    {
        deal({token: lpToken, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: lpToken,
            tokenOut: token0,
            callData: abi.encodeWithSignature(
                curvePool.isCrypto()
                    ? "remove_liquidity_one_coin(uint256,uint256,uint256)"
                    : "remove_liquidity_one_coin(uint256,int128,uint256)",
                diffInputAmount,
                0,
                diffInputAmount / 2
                ),
            requiresApproval: false,
            validatesTokens: false
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.remove_diff_liquidity_one_coin(diffLeftoverAmount, uint256(0), 0.5e27);

        assertEq(tokensToEnable, token0Mask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? lpTokenMask : 0, "Incorrect tokensToDisable");
    }
}
