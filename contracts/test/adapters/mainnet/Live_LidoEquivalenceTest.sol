// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacade} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import {ILidoV1Adapter} from "../../../interfaces/lido/ILidoV1Adapter.sol";
import {LidoV1Gateway} from "../../../adapters/lido/LidoV1_WETHGateway.sol";
import {LidoV1_Calls, LidoV1_Multicaller} from "../../../multicall/lido/LidoV1_Calls.sol";

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

contract Live_LidoEquivalenceTest is DSTest, LiveEnvHelper {
    using CreditFacadeCalls for CreditFacadeMulticaller;
    using LidoV1_Calls for LidoV1_Multicaller;

    BalanceComparator comparator;

    Tokens[2] tokensToTrack = [Tokens.WETH, Tokens.STETH];

    function setUp() public liveOnly {
        _setUp();

        // STAGES
        string[2] memory stages = ["after_submit", "after_submitAll"];

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
        tokenTestSuite.approveMany(
            _getTokensToTrack(), USER, supportedContracts.addressOf(Contracts.LIDO_STETH_GATEWAY)
        );
    }

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

    /// HELPER

    function compareBehavior(
        ICreditFacade creditFacade,
        address lidoAddr,
        address accountToSaveBalances,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            LidoV1_Multicaller lido = LidoV1_Multicaller(lidoAddr);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(lido.submit(WAD)));
            comparator.takeSnapshot("after_submit", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(lido.submitAll()));
            comparator.takeSnapshot("after_submitAll", accountToSaveBalances);
        } else {
            LidoV1Gateway lido = LidoV1Gateway(payable(lidoAddr));

            evm.prank(USER);
            lido.submit(WAD, DUMB_ADDRESS);
            comparator.takeSnapshot("after_submit", accountToSaveBalances);

            uint256 balanceToSwap = tokenTestSuite.balanceOf(Tokens.WETH, accountToSaveBalances) - 1;
            evm.prank(USER);
            lido.submit(balanceToSwap, DUMB_ADDRESS);
            comparator.takeSnapshot("after_submitAll", accountToSaveBalances);
        }
    }

    /// @dev Opens credit account for USER and make amount of desired token equal
    /// amounts for USER and CA to be able to launch test for both
    function openCreditAccountWithEqualAmount(ICreditFacade creditFacade, uint256 accountAmount, uint256 mintAmount)
        internal
        returns (address creditAccount)
    {
        tokenTestSuite.mint(Tokens.WETH, USER, mintAmount);

        // Approve tokens
        tokenTestSuite.approve(Tokens.WETH, USER, address(creditFacade.creditManager()));

        evm.startPrank(USER);
        creditFacade.openCreditAccountMulticall(
            accountAmount,
            USER,
            multicallBuilder(
                CreditFacadeMulticaller(address(creditFacade)).addCollateral(
                    USER, tokenTestSuite.addressOf(Tokens.WETH), mintAmount
                )
            ),
            0
        );

        evm.stopPrank();

        creditAccount = creditFacade.creditManager().getCreditAccountOrRevert(USER);

        tokenTestSuite.alignBalances(_getTokensToTrack(), creditAccount, USER);
    }

    /// @dev [L-LDOET-1]: Lido adapter and normal account works identically
    function test_live_LDOET_01_Lido_adapter_and_normal_account_works_identically() public liveOnly {
        (, ICreditFacade creditFacade,, uint256 accountAmount) = lts.getActiveCM();

        uint256 amountToMint =
            lts.priceOracle().convert(accountAmount, creditFacade.underlying(), tokenTestSuite.addressOf(Tokens.WETH));

        address creditAccount = openCreditAccountWithEqualAmount(creditFacade, accountAmount, amountToMint);

        uint256 snapshot = evm.snapshot();

        compareBehavior(creditFacade, supportedContracts.addressOf(Contracts.LIDO_STETH_GATEWAY), USER, false);

        /// Stores save balances in memory, because all state data would be reverted afer snapshot
        BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(USER);

        evm.revertTo(snapshot);

        compareBehavior(
            creditFacade,
            lts.getAdapter(address(creditFacade.creditManager()), Contracts.LIDO_STETH_GATEWAY),
            creditAccount,
            true
        );

        comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);
    }
}
