// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IAaveV2_WrappedATokenAdapter} from "../../../../interfaces/aave/IAaveV2_WrappedATokenAdapter.sol";
import {WrappedAToken} from "../../../../helpers/aave/AaveV2_WrappedAToken.sol";
import {IAToken} from "../../../../integrations/aave/IAToken.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";

import {TokenType} from "@gearbox-protocol/sdk-gov/contracts/TokensData.sol";

import {
    AaveV2_WrappedATokenCalls,
    AaveV2_WrappedATokenMulticaller
} from "../../../multicall/aave/AaveV2_WrappedATokenCalls.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_AaveV2WrappedATokenEquivalenceTest is LiveTestHelper {
    using AaveV2_WrappedATokenCalls for AaveV2_WrappedATokenMulticaller;

    BalanceComparator comparator;

    function prepareComparator(address waToken) internal {
        address aToken = WrappedAToken(waToken).aToken();
        address underlying = WrappedAToken(waToken).underlying();

        Tokens[3] memory tokensToTrack = [
            tokenTestSuite.tokenIndexes(waToken),
            tokenTestSuite.tokenIndexes(underlying),
            tokenTestSuite.tokenIndexes(aToken)
        ];

        // STAGES
        string[8] memory stages = [
            "after_deposit",
            "after_depositDiff",
            "after_depositUnderlying",
            "after_depositDiffUnderlying",
            "after_withdraw",
            "after_withdrawDiff",
            "after_withdrawUnderlying",
            "after_withdrawDiffUnderlying"
        ];

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

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    function compareBehavior(
        address creditAccount,
        address waTokenAddr,
        address aToken,
        address underlying,
        uint256 baseUnit,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            AaveV2_WrappedATokenMulticaller waToken = AaveV2_WrappedATokenMulticaller(waTokenAddr);

            vm.startPrank(USER);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(waToken.deposit(baseUnit)));
            comparator.takeSnapshot("after_deposit", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(waToken.depositDiff(20 * baseUnit)));
            comparator.takeSnapshot("after_depositDiff", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(waToken.depositUnderlying(baseUnit)));
            comparator.takeSnapshot("after_depositUnderlying", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(waToken.depositDiffUnderlying(20 * baseUnit)));
            comparator.takeSnapshot("after_depositDiffUnderlying", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(waToken.withdraw(baseUnit)));
            comparator.takeSnapshot("after_withdraw", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(waToken.withdrawDiff(10 * baseUnit)));
            comparator.takeSnapshot("after_withdrawDiff", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(waToken.withdrawUnderlying(baseUnit)));
            comparator.takeSnapshot("after_withdrawUnderlying", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(waToken.withdrawDiffUnderlying(baseUnit)));
            comparator.takeSnapshot("after_withdrawDiffUnderlying", creditAccount);

            vm.stopPrank();
        } else {
            WrappedAToken waToken = WrappedAToken(waTokenAddr);

            vm.startPrank(creditAccount);

            waToken.deposit(baseUnit);
            comparator.takeSnapshot("after_deposit", creditAccount);

            uint256 balanceToSwap = IERC20(aToken).balanceOf(creditAccount) - 20 * baseUnit;
            waToken.deposit(balanceToSwap);
            comparator.takeSnapshot("after_depositDiff", creditAccount);

            waToken.depositUnderlying(baseUnit);
            comparator.takeSnapshot("after_depositUnderlying", creditAccount);

            balanceToSwap = IERC20(underlying).balanceOf(creditAccount) - 20 * baseUnit;
            waToken.depositUnderlying(balanceToSwap);
            comparator.takeSnapshot("after_depositDiffUnderlying", creditAccount);

            waToken.withdraw(baseUnit);
            comparator.takeSnapshot("after_withdraw", creditAccount);

            balanceToSwap = IERC20(waToken).balanceOf(creditAccount) - 10 * baseUnit;
            waToken.withdraw(balanceToSwap);
            comparator.takeSnapshot("after_withdrawDiff", creditAccount);

            waToken.withdrawUnderlying(baseUnit);
            comparator.takeSnapshot("after_withdrawUnderlying", creditAccount);

            balanceToSwap = IERC20(waToken).balanceOf(creditAccount) - baseUnit;
            waToken.withdrawUnderlying(balanceToSwap);
            comparator.takeSnapshot("after_withdrawDiffUnderlying", creditAccount);

            vm.stopPrank();
        }
    }

    function openCreditAccountWithUnderlying(address token, uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);
        tokenTestSuite.mint(token, creditAccount, amount);
    }

    /// @dev [L-WAV2ET-1]: Wrapped AToken adapters and original contracts work identically
    function test_live_WAV2ET_01_waToken_adapters_and_original_contracts_are_equivalent() public attachOrLiveTest {
        address[] memory adapters = creditConfigurator.allowedAdapters();

        for (uint256 i = 0; i < adapters.length; ++i) {
            if (IAdapter(adapters[i])._gearboxAdapterType() != AdapterType.AAVE_V2_WRAPPED_ATOKEN) continue;

            uint256 snapshot0 = vm.snapshot();

            address waToken = IAaveV2_WrappedATokenAdapter(adapters[i]).targetContract();
            address aToken = IAaveV2_WrappedATokenAdapter(adapters[i]).aToken();
            address underlying = IAaveV2_WrappedATokenAdapter(adapters[i]).underlying();

            address creditAccount =
                openCreditAccountWithUnderlying(underlying, 3000 * 10 ** IERC20Metadata(underlying).decimals());

            tokenTestSuite.approve(underlying, creditAccount, waToken);
            tokenTestSuite.approve(aToken, creditAccount, waToken);

            uint256 snapshot1 = vm.snapshot();

            prepareComparator(waToken);

            compareBehavior(
                creditAccount, waToken, aToken, underlying, 10 ** IERC20Metadata(underlying).decimals(), false
            );

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot1);

            prepareComparator(waToken);

            compareBehavior(
                creditAccount, adapters[i], aToken, underlying, 10 ** IERC20Metadata(underlying).decimals(), true
            );

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots, 0);

            vm.revertTo(snapshot0);
        }
    }
}
