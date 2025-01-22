// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {
    CollateralDebtData, CollateralCalcTask
} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IAaveV2_LendingPoolAdapter} from "../../../../interfaces/aave/IAaveV2_LendingPoolAdapter.sol";
import {ILendingPool} from "../../../../integrations/aave/ILendingPool.sol";
import {IAToken} from "../../../../integrations/aave/IAToken.sol";

import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";

import {TokenType} from "@gearbox-protocol/sdk-gov/contracts/TokensData.sol";

import {
    AaveV2_LendingPoolCalls, AaveV2_LendingPoolMulticaller
} from "../../../multicall/aave/AaveV2_LendingPoolCalls.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_AaveV2LendingPoolEquivalenceTest is LiveTestHelper {
    using AaveV2_LendingPoolCalls for AaveV2_LendingPoolMulticaller;

    BalanceComparator comparator;

    function prepareComparator(address aToken, address underlying) internal {
        uint256[2] memory tokensToTrack = [tokenTestSuite.tokenIndexes(underlying), tokenTestSuite.tokenIndexes(aToken)];

        // STAGES
        string[4] memory stages = ["after_deposit", "after_depositDiff", "after_withdraw", "after_withdrawDiff"];

        /// @notice Sets comparator for this equivalence test

        uint256 len = stages.length;
        string[] memory _stages = new string[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _stages[i] = stages[i];
            }
        }

        len = tokensToTrack.length;
        uint256[] memory _tokensToTrack = new uint256[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _tokensToTrack[i] = tokensToTrack[i];
            }
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    function compareBehavior(
        address creditAccount,
        address lendingPoolAddr,
        address aToken,
        address underlying,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            AaveV2_LendingPoolMulticaller lendingPool = AaveV2_LendingPoolMulticaller(lendingPoolAddr);

            vm.startPrank(USER);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(lendingPool.deposit(underlying, WAD, creditAccount, 0))
            );
            comparator.takeSnapshot("after_deposit", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(lendingPool.depositDiff(underlying, 20 * WAD)));
            comparator.takeSnapshot("after_depositDiff", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(lendingPool.withdraw(underlying, WAD, creditAccount))
            );
            comparator.takeSnapshot("after_withdraw", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(lendingPool.withdrawDiff(underlying, WAD)));
            comparator.takeSnapshot("after_withdrawDiff", creditAccount);

            vm.stopPrank();
        } else {
            ILendingPool lendingPool = ILendingPool(lendingPoolAddr);

            vm.startPrank(creditAccount);

            lendingPool.deposit(underlying, WAD, creditAccount, 0);
            comparator.takeSnapshot("after_deposit", creditAccount);

            uint256 balanceToSwap = tokenTestSuite.balanceOf(underlying, creditAccount) - 20 * WAD;
            lendingPool.deposit(underlying, balanceToSwap, creditAccount, 0);
            comparator.takeSnapshot("after_depositDiff", creditAccount);

            lendingPool.withdraw(underlying, WAD, creditAccount);
            comparator.takeSnapshot("after_withdraw", creditAccount);

            balanceToSwap = tokenTestSuite.balanceOf(aToken, creditAccount) - WAD;
            lendingPool.withdraw(underlying, balanceToSwap, creditAccount);
            comparator.takeSnapshot("after_withdrawDiff", creditAccount);

            vm.stopPrank();
        }
    }

    function openCreditAccountWithUnderlying(address token, uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);
        tokenTestSuite.mint(token, creditAccount, amount);
    }

    /// @dev [L-AV2ET-1]: AaveV2 adapter and normal account works identically
    function test_live_AV2ET_01_AaveV2_adapter_and_normal_account_works_identically() public attachOrLiveTest {
        uint256 collateralTokensCount = creditManager.collateralTokensCount();

        for (uint256 i = 0; i < collateralTokensCount; ++i) {
            address token = creditManager.getTokenByMask(1 << i);

            if (tokenTestSuite.tokenTypes(tokenTestSuite.tokenIndexes(token)) != TokenType.AAVE_V2_A_TOKEN) continue;

            address underlying = IAToken(token).UNDERLYING_ASSET_ADDRESS();

            prepareComparator(token, underlying);

            address creditAccount =
                openCreditAccountWithUnderlying(underlying, 100 * 10 ** IERC20Metadata(underlying).decimals());

            address lendingPoolAdapter = getAdapter(address(creditManager), Contracts.AAVE_V2_LENDING_POOL);

            tokenTestSuite.approve(
                underlying, creditAccount, supportedContracts.addressOf(Contracts.AAVE_V2_LENDING_POOL)
            );

            tokenTestSuite.approve(token, creditAccount, supportedContracts.addressOf(Contracts.AAVE_V2_LENDING_POOL));

            uint256 snapshot = vm.snapshot();

            compareBehavior(
                creditAccount, supportedContracts.addressOf(Contracts.AAVE_V2_LENDING_POOL), token, underlying, false
            );

            /// Stores save balances in memory, because all state data would be reverted afer snapshot
            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot);

            compareBehavior(creditAccount, lendingPoolAdapter, token, underlying, true);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
        }
    }

    function test_diag_profits() public attachOrLiveTest {
        uint256 cmProfit = 0;

        address[] memory creditAccounts = creditManager.creditAccounts();

        for (uint256 j = 0; j < creditAccounts.length; ++j) {
            CollateralDebtData memory cdd =
                creditManager.calcDebtAndCollateral(creditAccounts[j], CollateralCalcTask.DEBT_ONLY);

            cmProfit += cdd.accruedFees;
        }

        emit log_address(address(creditManager));
        emit log_uint(cmProfit);
    }

    function test_diag_pf() public attachOrLiveTest {
        emit log_uint(priceOracle.getPrice(tokenTestSuite.addressOf(TOKEN_ezETH)));
    }
}
