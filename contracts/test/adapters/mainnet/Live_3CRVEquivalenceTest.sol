// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacade} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import {ICurvePool3Assets} from "../../../integrations/curve/ICurvePool_3.sol";
import {ICurveV1_3AssetsAdapter} from "../../../interfaces/curve/ICurveV1_3AssetsAdapter.sol";
import {CurveV1Calls, CurveV1Multicaller} from "../../../multicall/curve/CurveV1_Calls.sol";

import {Tokens} from "../../config/Tokens.sol";
import {Contracts} from "../../config/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {
    CreditFacadeCalls,
    CreditFacadeMulticaller
} from "@gearbox-protocol/core-v2/contracts/multicall/CreditFacadeCalls.sol";
// TEST
import "@gearbox-protocol/core-v2/contracts/test/lib/constants.sol";

// SUITES
import {LiveEnvTestSuite} from "../../suites/LiveEnvTestSuite.sol";
import {LiveEnvHelper} from "../../suites/LiveEnvHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../helpers/BalanceComparator.sol";

contract Live_3CRVEquivalenceTest is DSTest, LiveEnvHelper {
    using CreditFacadeCalls for CreditFacadeMulticaller;
    using CurveV1Calls for CurveV1Multicaller;

    BalanceComparator comparator;
    Tokens[4] tokensToTrack = [Tokens._3Crv, Tokens.DAI, Tokens.USDC, Tokens.USDT];

    function setUp() public liveOnly {
        _setUp();

        // STAGES
        string[9] memory stages = [
            "after_exchange",
            "after_add_liquidity",
            "after_remove_liquidity",
            "after_remove_liquidity_one_coin",
            "after_remove_liquidity_imbalance",
            "after_add_liquidity_one_coin",
            "after_exchange_all",
            "after_add_all_liquidity_one_coin",
            "after_remove_all_liquidity_one_coin"
        ];

        /// @notice Sets comparator for this equivalence test

        uint256 len = stages.length;
        string[] memory _stages = new string[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _stages[i] = stages[i];
            }
        }

        comparator = new BalanceComparator(
            _stages,
            _getTokensToTrack(),
            tokenTestSuite
        );

        /// @notice Approves all tracked tokens for USER
        tokenTestSuite.approveMany(_getTokensToTrack(), USER, supportedContracts.addressOf(Contracts.CURVE_3CRV_POOL));
    }

    /// HELPER

    function _getTokensToTrack() internal view returns (Tokens[] memory) {
        uint256 len = tokensToTrack.length;
        Tokens[] memory _tokensToTrack = new Tokens[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _tokensToTrack[i] = tokensToTrack[i];
            }
        }

        return _tokensToTrack;
    }

    function compareBehavior(
        ICreditFacade creditFacade,
        address curvePoolAddr,
        address accountToSaveBalances,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(pool.exchange(int128(0), int128(2), 2000 * WAD, 1500 * (10 ** 6))));
            comparator.takeSnapshot("after_exchange", accountToSaveBalances);

            uint256[3] memory amounts = [1000 * WAD, 0, 1000 * (10 ** 6)];

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(pool.add_liquidity(amounts, 0)));
            comparator.takeSnapshot("after_add_liquidity", accountToSaveBalances);

            amounts = [uint256(0), 0, 0];

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(pool.remove_liquidity(500 * WAD, amounts)));
            comparator.takeSnapshot("after_remove_liquidity", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(pool.remove_liquidity_one_coin(500 * WAD, int128(1), 0)));
            comparator.takeSnapshot("after_remove_liquidity_one_coin", accountToSaveBalances);

            amounts = [500 * WAD, 0, 100 * (10 ** 6)];

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(pool.remove_liquidity_imbalance(amounts, type(uint256).max)));
            comparator.takeSnapshot("after_remove_liquidity_imbalance", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(pool.add_liquidity_one_coin(100 * WAD, int128(0), 50 * WAD)));
            comparator.takeSnapshot("after_add_liquidity_one_coin", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(pool.exchange_all(int128(0), int128(1), RAY / 2 / 10 ** 12)));
            comparator.takeSnapshot("after_exchange_all", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(pool.add_all_liquidity_one_coin(int128(1), (RAY * 10 ** 12) / 2)));
            comparator.takeSnapshot("after_add_all_liquidity_one_coin", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(pool.remove_all_liquidity_one_coin(int128(0), RAY / 2)));
            comparator.takeSnapshot("after_remove_all_liquidity_one_coin", accountToSaveBalances);
        } else {
            ICurvePool3Assets pool = ICurvePool3Assets(curvePoolAddr);

            evm.prank(USER);
            pool.exchange(int128(0), 2, 2000 * WAD, 1500 * (10 ** 6));
            comparator.takeSnapshot("after_exchange", accountToSaveBalances);

            uint256[3] memory amounts = [1000 * WAD, 0, 1000 * (10 ** 6)];

            evm.prank(USER);
            pool.add_liquidity(amounts, 0);
            comparator.takeSnapshot("after_add_liquidity", accountToSaveBalances);

            amounts = [uint256(0), 0, 0];

            evm.prank(USER);
            pool.remove_liquidity(500 * WAD, amounts);
            comparator.takeSnapshot("after_remove_liquidity", accountToSaveBalances);

            evm.prank(USER);
            pool.remove_liquidity_one_coin(500 * WAD, int128(1), 0);
            comparator.takeSnapshot("after_remove_liquidity_one_coin", accountToSaveBalances);

            amounts = [500 * WAD, 0, 100 * (10 ** 6)];

            evm.prank(USER);
            pool.remove_liquidity_imbalance(amounts, type(uint256).max);
            comparator.takeSnapshot("after_remove_liquidity_imbalance", accountToSaveBalances);

            evm.prank(USER);
            pool.add_liquidity([100 * WAD, 0, 0], 50 * WAD);
            comparator.takeSnapshot("after_add_liquidity_one_coin", accountToSaveBalances);

            uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens.DAI, accountToSaveBalances) - 1;
            evm.prank(USER);
            pool.exchange(int128(0), int128(1), balanceToSwap, balanceToSwap / (2 * 10 ** 12));
            comparator.takeSnapshot("after_exchange_all", accountToSaveBalances);

            balanceToSwap = tokenTestSuite.balanceOf(Tokens.USDC, accountToSaveBalances) - 1;
            evm.prank(USER);
            pool.add_liquidity([0, balanceToSwap, 0], (balanceToSwap * 10 ** 12) / 2);
            comparator.takeSnapshot("after_add_all_liquidity_one_coin", accountToSaveBalances);

            balanceToSwap = tokenTestSuite.balanceOf(Tokens._3Crv, accountToSaveBalances) - 1;
            evm.prank(USER);
            pool.remove_liquidity_one_coin(balanceToSwap, int128(0), balanceToSwap / 2);
            comparator.takeSnapshot("after_remove_all_liquidity_one_coin", accountToSaveBalances);
        }
    }

    /// @dev Opens credit account for USER and make amount of desired token equal
    /// amounts for USER and CA to be able to launch test for both
    function openCreditAccountWithEqualAmount(ICreditFacade creditFacade, uint256 accountAmount, uint256 amountToMint)
        internal
        returns (address creditAccount)
    {
        tokenTestSuite.mint(Tokens.DAI, USER, amountToMint);

        // Approve tokens
        tokenTestSuite.approve(Tokens.DAI, USER, address(creditFacade.creditManager()));

        evm.startPrank(USER);
        creditFacade.openCreditAccountMulticall(
            accountAmount,
            USER,
            multicallBuilder(
                CreditFacadeMulticaller(address(creditFacade)).addCollateral(
                    USER, tokenTestSuite.addressOf(Tokens.DAI), amountToMint
                )
            ),
            0
        );

        evm.stopPrank();

        creditAccount = creditFacade.creditManager().getCreditAccountOrRevert(USER);

        tokenTestSuite.alignBalances(_getTokensToTrack(), creditAccount, USER);
    }

    /// @dev [L-CRVET-1]: 3CRV adapter and normal account works identically
    function test_live_CRVET_01_3CRV_adapter_and_normal_account_works_identically() public liveOnly {
        (, ICreditFacade creditFacade,, uint256 accountAmount) = lts.getActiveCM();

        uint256 amountToMint =
            lts.priceOracle().convert(accountAmount, creditFacade.underlying(), tokenTestSuite.addressOf(Tokens.DAI));

        address creditAccount = openCreditAccountWithEqualAmount(creditFacade, accountAmount, amountToMint);

        uint256 snapshot = evm.snapshot();

        compareBehavior(creditFacade, supportedContracts.addressOf(Contracts.CURVE_3CRV_POOL), USER, false);

        /// Stores save balances in memory, because all state data would be reverted afer snapshot
        BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(USER);

        evm.revertTo(snapshot);

        compareBehavior(
            creditFacade,
            lts.getAdapter(address(creditFacade.creditManager()), Contracts.CURVE_3CRV_POOL),
            creditAccount,
            true
        );

        comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
    }
}
