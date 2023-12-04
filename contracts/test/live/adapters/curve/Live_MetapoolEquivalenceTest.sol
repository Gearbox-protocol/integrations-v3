// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICurvePool2Assets} from "../../../../integrations/curve/ICurvePool_2.sol";
import {ICurveV1Adapter} from "../../../../interfaces/curve/ICurveV1Adapter.sol";
import {ICurveV1_2AssetsAdapter} from "../../../../interfaces/curve/ICurveV1_2AssetsAdapter.sol";
import {CurveV1Calls, CurveV1Multicaller} from "../../../multicall/curve/CurveV1_Calls.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_CurveMetapoolTest is LiveTestHelper {
    using CurveV1Calls for CurveV1Multicaller;

    Contracts[2] curveMetapools = [Contracts.CURVE_FRAX_POOL, Contracts.CURVE_LUSD_POOL];

    string[] _stages;

    function setUp() public attachOrLiveTest {
        _setUp();

        // STAGES
        string[11] memory stages = [
            "after_exchange",
            "after_exchange_underlying",
            "after_add_liquidity",
            "after_remove_liquidity",
            "after_remove_liquidity_one_coin",
            "after_remove_liquidity_imbalance",
            "after_add_liquidity_one_coin",
            "after_exchange_diff",
            "after_add_diff_liquidity_one_coin",
            "after_remove_diff_liquidity_one_coin",
            "after_exchange_diff_underlying"
        ];

        /// @notice Sets comparator for this equivalence test

        uint256 len = stages.length;
        _stages = new string[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _stages[i] = stages[i];
            }
        }
    }

    // /// HELPER

    function compareBehavior(address creditAccount, address curvePoolAddr, bool isAdapter, BalanceComparator comparator)
        internal
    {
        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);

            vm.startPrank(USER);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.exchange(int128(1), int128(0), 3000 * WAD, 2000 * WAD))
            );
            comparator.takeSnapshot("after_exchange", creditAccount);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(pool.exchange_underlying(int128(0), int128(2), 500 * WAD, 125 * (10 ** 6)))
            );
            comparator.takeSnapshot("after_exchange_underlying", creditAccount);

            uint256[2] memory amounts = [1500 * WAD, 1500 * WAD];

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.add_liquidity(amounts, 0)));
            comparator.takeSnapshot("after_add_liquidity", creditAccount);

            amounts = [uint256(0), 0];

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.remove_liquidity(500 * WAD, amounts)));
            comparator.takeSnapshot("after_remove_liquidity", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.remove_liquidity_one_coin(500 * WAD, int128(1), 0))
            );
            comparator.takeSnapshot("after_remove_liquidity_one_coin", creditAccount);

            amounts = [100 * WAD, 500 * WAD];

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.remove_liquidity_imbalance(amounts, type(uint256).max))
            );
            comparator.takeSnapshot("after_remove_liquidity_imbalance", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.add_liquidity_one_coin(100 * WAD, 1, 50 * WAD))
            );
            comparator.takeSnapshot("after_add_liquidity_one_coin", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.exchange_diff(1, 0, 100 * WAD, RAY / 2)));
            comparator.takeSnapshot("after_exchange_diff", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.add_diff_liquidity_one_coin(100 * WAD, 0, RAY / 2))
            );
            comparator.takeSnapshot("after_add_diff_liquidity_one_coin", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.remove_diff_liquidity_one_coin(100 * WAD, 0, RAY / 2))
            );
            comparator.takeSnapshot("after_remove_diff_liquidity_one_coin", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.exchange_diff_underlying(0, 1, 100 * WAD, RAY / 2))
            );
            comparator.takeSnapshot("after_exchange_diff_underlying", creditAccount);

            vm.stopPrank();
        } else {
            ICurvePool2Assets pool = ICurvePool2Assets(curvePoolAddr);

            vm.startPrank(creditAccount);

            pool.exchange(int128(1), int128(0), 3000 * WAD, 2000 * WAD);
            comparator.takeSnapshot("after_exchange", creditAccount);

            pool.exchange_underlying(int128(0), int128(2), 500 * WAD, 125 * (10 ** 6));
            comparator.takeSnapshot("after_exchange_underlying", creditAccount);

            uint256[2] memory amounts = [1500 * WAD, 1500 * WAD];

            pool.add_liquidity(amounts, 0);
            comparator.takeSnapshot("after_add_liquidity", creditAccount);

            amounts = [uint256(0), 0];

            pool.remove_liquidity(500 * WAD, amounts);
            comparator.takeSnapshot("after_remove_liquidity", creditAccount);

            pool.remove_liquidity_one_coin(500 * WAD, int128(1), 0);
            comparator.takeSnapshot("after_remove_liquidity_one_coin", creditAccount);

            amounts = [100 * WAD, 500 * WAD];

            pool.remove_liquidity_imbalance(amounts, type(uint256).max);
            comparator.takeSnapshot("after_remove_liquidity_imbalance", creditAccount);

            pool.add_liquidity([0, 100 * WAD], 50 * WAD);
            comparator.takeSnapshot("after_add_liquidity_one_coin", creditAccount);

            uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens._3Crv, creditAccount) - 100 * WAD;
            pool.exchange(int128(1), int128(0), balanceToSwap, balanceToSwap / 2);
            comparator.takeSnapshot("after_exchange_diff", creditAccount);

            Tokens tokenZero = tokenTestSuite.tokenIndexes(pool.coins(uint256(0)));
            uint8 tZeroDecimals = IERC20Metadata(tokenTestSuite.addressOf(tokenZero)).decimals();
            balanceToSwap = tokenTestSuite.balanceOf(tokenZero, creditAccount) - 100 * 10 ** tZeroDecimals;
            pool.add_liquidity([balanceToSwap, 0], balanceToSwap / 2);
            comparator.takeSnapshot("after_add_diff_liquidity_one_coin", creditAccount);

            Tokens lpToken = tokenTestSuite.tokenIndexes(address(pool));
            balanceToSwap = tokenTestSuite.balanceOf(lpToken, creditAccount) - 100 * WAD;
            pool.remove_liquidity_one_coin(balanceToSwap, int128(0), balanceToSwap / 2);
            comparator.takeSnapshot("after_remove_diff_liquidity_one_coin", creditAccount);

            balanceToSwap = tokenTestSuite.balanceOf(tokenZero, creditAccount) - 100 * 10 ** tZeroDecimals;
            pool.exchange_underlying(int128(0), int128(1), balanceToSwap, balanceToSwap / 2);
            comparator.takeSnapshot("after_exchange_diff_underlying", creditAccount);

            vm.stopPrank();
        }
    }

    /// @dev Opens credit account for USER and make amount of desired token equal
    /// amounts for USER and CA to be able to launch test for both
    function openCreditAccountWith3CRV(uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);
        tokenTestSuite.mint(Tokens._3Crv, creditAccount, amount);
    }

    function prepareComparator(address curveAdapter) internal returns (BalanceComparator comparator) {
        address targetContract = ICurveV1Adapter(curveAdapter).targetContract();

        Tokens[] memory tokensToTrack = new Tokens[](7);

        tokensToTrack[0] = tokenTestSuite.tokenIndexes(ICurveV1Adapter(curveAdapter).token0());
        tokensToTrack[1] = tokenTestSuite.tokenIndexes(ICurveV1Adapter(curveAdapter).token1());
        tokensToTrack[2] = tokenTestSuite.tokenIndexes(ICurveV1Adapter(curveAdapter).underlying0());
        tokensToTrack[3] = tokenTestSuite.tokenIndexes(ICurveV1Adapter(curveAdapter).underlying1());
        tokensToTrack[4] = tokenTestSuite.tokenIndexes(ICurveV1Adapter(curveAdapter).underlying2());
        tokensToTrack[5] = tokenTestSuite.tokenIndexes(ICurveV1Adapter(curveAdapter).underlying3());
        tokensToTrack[6] = tokenTestSuite.tokenIndexes(ICurveV1Adapter(curveAdapter).token());

        comparator = new BalanceComparator(_stages, tokensToTrack, tokenTestSuite);
    }

    /// @dev [L-CRVET-2]: Metapool adapters and normal accounts works identically
    function test_live_CRVET_02_Metapool_adapter_and_normal_account_works_identically() public {
        for (uint256 i = 0; i < curveMetapools.length; ++i) {
            uint256 snapshot0 = vm.snapshot();

            address curveAdapter = getAdapter(address(creditManager), curveMetapools[i]);

            if (curveAdapter == address(0)) {
                vm.revertTo(snapshot0);
                continue;
            }

            address creditAccount = openCreditAccountWith3CRV(10000 * WAD);

            tokenTestSuite.approve(
                ICurveV1Adapter(curveAdapter).token0(), creditAccount, supportedContracts.addressOf(curveMetapools[i])
            );

            tokenTestSuite.approve(
                ICurveV1Adapter(curveAdapter).token1(), creditAccount, supportedContracts.addressOf(curveMetapools[i])
            );

            tokenTestSuite.approve(
                ICurveV1Adapter(curveAdapter).underlying0(),
                creditAccount,
                supportedContracts.addressOf(curveMetapools[i])
            );

            tokenTestSuite.approve(
                ICurveV1Adapter(curveAdapter).underlying1(),
                creditAccount,
                supportedContracts.addressOf(curveMetapools[i])
            );

            tokenTestSuite.approve(
                ICurveV1Adapter(curveAdapter).underlying2(),
                creditAccount,
                supportedContracts.addressOf(curveMetapools[i])
            );

            tokenTestSuite.approve(
                ICurveV1Adapter(curveAdapter).underlying3(),
                creditAccount,
                supportedContracts.addressOf(curveMetapools[i])
            );

            tokenTestSuite.approve(
                ICurveV1Adapter(curveAdapter).token(), creditAccount, supportedContracts.addressOf(curveMetapools[i])
            );

            uint256 snapshot1 = vm.snapshot();

            BalanceComparator comparator = prepareComparator(curveAdapter);

            compareBehavior(creditAccount, supportedContracts.addressOf(curveMetapools[i]), false, comparator);

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot1);

            comparator = prepareComparator(curveAdapter);

            compareBehavior(creditAccount, curveAdapter, true, comparator);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);

            vm.revertTo(snapshot0);
        }
    }
}
