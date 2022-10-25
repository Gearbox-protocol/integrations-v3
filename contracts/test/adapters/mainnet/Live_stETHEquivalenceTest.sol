// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICreditFacade } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import { ICurvePool2Assets } from "../../../integrations/curve/ICurvePool_2.sol";
import { ICurveV1_2AssetsAdapter } from "../../../interfaces/curve/ICurveV1_2AssetsAdapter.sol";
import { Tokens } from "../../config/Tokens.sol";
import { Contracts } from "../../config/SupportedContracts.sol";

import { MultiCall } from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import { CreditFacadeCalls, CreditFacadeMulticaller } from "@gearbox-protocol/core-v2/contracts/multicall/CreditFacadeCalls.sol";
// TEST
import "@gearbox-protocol/core-v2/contracts/test/lib/constants.sol";

// SUITES
import { LiveEnvTestSuite } from "../../suites/LiveEnvTestSuite.sol";
import { LiveEnvHelper } from "../../suites/LiveEnvHelper.sol";
import { BalanceComparator, BalanceBackup } from "../../helpers/BalanceComparator.sol";

contract Live_CurveStETHEquivalenceTest is DSTest, LiveEnvHelper {
    using CreditFacadeCalls for CreditFacadeMulticaller;
    BalanceComparator comparator;

    function setUp() public liveOnly {
        _setUp();

        // TOKENS TO TRACK ["crvFRAX", "FRAX", "USDC"]
        Tokens[3] memory tokensToTrack = [
            Tokens.steCRV,
            Tokens.WETH,
            Tokens.STETH
        ];

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

        len = tokensToTrack.length;
        Tokens[] memory _tokensToTrack = new Tokens[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _tokensToTrack[i] = tokensToTrack[i];
            }
        }

        comparator = new BalanceComparator(
            _stages,
            _tokensToTrack,
            tokenTestSuite
        );

        /// @notice Approves all tracked tokens for USER
        tokenTestSuite.approveMany(
            _tokensToTrack,
            USER,
            supportedContracts.addressOf(Contracts.CURVE_STETH_GATEWAY)
        );
    }

    /// HELPER

    function compareBehavior(
        address curvePoolAddr,
        address accountToSaveBalances
    ) internal {
        ICurvePool2Assets curvePool = ICurvePool2Assets(curvePoolAddr);

        evm.prank(USER);
        curvePool.exchange(0, 1, 5 * WAD, WAD);
        comparator.takeSnapshot("after_exchange", accountToSaveBalances);

        uint256[2] memory amounts = [4 * WAD, 4 * WAD];

        evm.prank(USER);
        curvePool.add_liquidity(amounts, 0);
        comparator.takeSnapshot("after_add_liquidity", accountToSaveBalances);

        amounts = [uint256(0), 0];

        evm.prank(USER);
        curvePool.remove_liquidity(WAD, amounts);
        comparator.takeSnapshot(
            "after_remove_liquidity",
            accountToSaveBalances
        );

        evm.prank(USER);
        curvePool.remove_liquidity_one_coin(WAD, 1, 0);
        comparator.takeSnapshot(
            "after_remove_liquidity_one_coin",
            accountToSaveBalances
        );

        amounts = [WAD, WAD / 5];

        evm.prank(USER);
        curvePool.remove_liquidity_imbalance(amounts, 2 * WAD);
        comparator.takeSnapshot(
            "after_remove_liquidity_imbalance",
            accountToSaveBalances
        );
    }

    function compareExtraFunctions(
        address curvePoolAddr,
        address accountToSaveBalances,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            ICurveV1_2AssetsAdapter pool = ICurveV1_2AssetsAdapter(
                curvePoolAddr
            );

            evm.prank(USER);
            pool.add_liquidity_one_coin(WAD, 0, WAD / 2);
            comparator.takeSnapshot(
                "after_add_liquidity_one_coin",
                accountToSaveBalances
            );

            evm.prank(USER);
            pool.exchange_all(0, 1, RAY / 2);
            comparator.takeSnapshot(
                "after_exchange_all",
                accountToSaveBalances
            );

            evm.prank(USER);
            pool.add_all_liquidity_one_coin(1, RAY / 2);
            comparator.takeSnapshot(
                "after_add_all_liquidity_one_coin",
                accountToSaveBalances
            );

            evm.prank(USER);
            pool.remove_all_liquidity_one_coin(0, RAY / 2);
            comparator.takeSnapshot(
                "after_remove_all_liquidity_one_coin",
                accountToSaveBalances
            );
        } else {
            ICurvePool2Assets pool = ICurvePool2Assets(curvePoolAddr);

            evm.prank(USER);
            pool.add_liquidity([WAD, 0], WAD / 2);
            comparator.takeSnapshot(
                "after_add_liquidity_one_coin",
                accountToSaveBalances
            );

            uint256 balanceToSwap = tokenTestSuite.balanceOf(
                Tokens.WETH,
                accountToSaveBalances
            ) - 1;
            evm.prank(USER);
            pool.exchange(0, 1, balanceToSwap, balanceToSwap / 2);
            comparator.takeSnapshot(
                "after_exchange_all",
                accountToSaveBalances
            );

            balanceToSwap =
                tokenTestSuite.balanceOf(Tokens.STETH, accountToSaveBalances) -
                1;
            evm.prank(USER);
            pool.add_liquidity([0, balanceToSwap], balanceToSwap / 2);
            comparator.takeSnapshot(
                "after_add_all_liquidity_one_coin",
                accountToSaveBalances
            );

            balanceToSwap =
                tokenTestSuite.balanceOf(Tokens.steCRV, accountToSaveBalances) -
                1;
            evm.prank(USER);
            pool.remove_liquidity_one_coin(balanceToSwap, 0, balanceToSwap / 2);
            comparator.takeSnapshot(
                "after_remove_all_liquidity_one_coin",
                accountToSaveBalances
            );
        }
    }

    /// @dev Opens credit account for USER and make amount of desired token equal
    /// amounts for USER and CA to be able to launch test for both
    function openCreditAccountWithEqualAmount(uint256 amount)
        internal
        returns (address creditAccount)
    {
        ICreditFacade creditFacade = lts.creditFacades(Tokens.WETH);

        tokenTestSuite.mint(Tokens.WETH, USER, 3 * amount);

        // Approve tokens
        tokenTestSuite.approve(
            Tokens.WETH,
            USER,
            address(lts.creditManagers(Tokens.WETH))
        );

        evm.startPrank(USER);
        creditFacade.openCreditAccountMulticall(
            amount,
            USER,
            multicallBuilder(
                CreditFacadeMulticaller(address(creditFacade)).addCollateral(
                    USER,
                    tokenTestSuite.addressOf(Tokens.WETH),
                    amount
                )
            ),
            0
        );

        evm.stopPrank();

        creditAccount = lts
            .creditManagers(Tokens.WETH)
            .getCreditAccountOrRevert(USER);
    }

    /// @dev [L-CRVET-6]: stETH adapter and normal account works identically
    function test_live_CRVET_06_stETH_adapter_and_normal_account_works_identically()
        public
        liveOnly
    {
        ICreditFacade creditFacade = lts.creditFacades(Tokens.WETH);

        (uint256 minAmount, ) = creditFacade.limits();

        address creditAccount = openCreditAccountWithEqualAmount(minAmount);

        uint256 snapshot = evm.snapshot();

        compareBehavior(
            supportedContracts.addressOf(Contracts.CURVE_STETH_GATEWAY),
            USER
        );
        compareExtraFunctions(
            supportedContracts.addressOf(Contracts.CURVE_STETH_GATEWAY),
            USER,
            false
        );

        /// Stores save balances in memory, because all state data would be reverted afer snapshot
        BalanceBackup[] memory savedBalanceSnapshots = comparator
            .exportSnapshots(USER);

        evm.revertTo(snapshot);

        compareBehavior(
            lts.getAdapter(Tokens.WETH, Contracts.CURVE_STETH_GATEWAY),
            creditAccount
        );
        compareExtraFunctions(
            lts.getAdapter(Tokens.WETH, Contracts.CURVE_STETH_GATEWAY),
            creditAccount,
            true
        );

        comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
    }
}
