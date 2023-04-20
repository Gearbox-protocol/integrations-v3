// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacade} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import {IYVault} from "../../../integrations/yearn/IYVault.sol";
import {IYearnV2Adapter} from "../../../interfaces/yearn/IYearnV2Adapter.sol";
import {YearnV2_Calls, YearnV2_Multicaller} from "../../../multicall/yearn/YearnV2_Calls.sol";

import {Tokens} from "../../config/Tokens.sol";
import {Contracts} from "../../config/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {
    CreditFacadeCalls,
    CreditFacadeMulticaller
} from "@gearbox-protocol/core-v2/contracts/multicall/CreditFacadeCalls.sol";
import {AddressList} from "@gearbox-protocol/core-v2/contracts/libraries/AddressList.sol";
// TEST
import "@gearbox-protocol/core-v2/contracts/test/lib/constants.sol";

// SUITES
import {LiveEnvTestSuite} from "../../suites/LiveEnvTestSuite.sol";
import {LiveEnvHelper} from "../../suites/LiveEnvHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../helpers/BalanceComparator.sol";

contract Live_YearnEquivalenceTest is DSTest, LiveEnvHelper {
    using CreditFacadeCalls for CreditFacadeMulticaller;
    using YearnV2_Calls for YearnV2_Multicaller;
    using AddressList for address[];

    string[7] stages = [
        "after_deposit_uint256_address",
        "after_deposit_uint256",
        "after_deposit",
        "after_withdraw_uint256_address_uint256",
        "after_withdraw_uint256_address",
        "after_withdraw_uint256",
        "after_withdraw"
    ];

    Contracts[6] yearnVaults = [
        Contracts.YEARN_DAI_VAULT,
        Contracts.YEARN_USDC_VAULT,
        Contracts.YEARN_WETH_VAULT,
        Contracts.YEARN_WBTC_VAULT,
        Contracts.YEARN_CURVE_FRAX_VAULT,
        Contracts.YEARN_CURVE_STETH_VAULT
    ];

    string[] _stages;

    function setUp() public liveOnly {
        _setUp();

        /// @notice Sets comparator for this equivalence test

        uint256 len = stages.length;
        _stages = new string[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _stages[i] = stages[i];
            }
        }
    }

    function _getTokensToTrack(address vaultAdapter) internal view returns (Tokens[] memory) {
        address[] memory tokensToTrack = new address[](2);

        tokensToTrack[0] = IYearnV2Adapter(vaultAdapter).token();
        tokensToTrack[1] = IYearnV2Adapter(vaultAdapter).targetContract();

        uint256 len = tokensToTrack.length;
        Tokens[] memory _tokensToTrack = new Tokens[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _tokensToTrack[i] = tokenTestSuite.tokenIndexes(tokensToTrack[i]);
            }
        }

        return _tokensToTrack;
    }

    /// HELPER

    function compareBehavior(
        ICreditFacade creditFacade,
        address vaultAddress,
        address accountToSaveBalances,
        uint256 baseUnit,
        bool isAdapter,
        BalanceComparator comparator
    ) internal {
        if (isAdapter) {
            YearnV2_Multicaller vault = YearnV2_Multicaller(vaultAddress);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.deposit(5 * baseUnit, accountToSaveBalances)));
            comparator.takeSnapshot("after_deposit_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.deposit(5 * baseUnit)));
            comparator.takeSnapshot("after_deposit_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.deposit()));
            comparator.takeSnapshot("after_deposit", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.withdraw(3 * baseUnit, accountToSaveBalances, 10)));
            comparator.takeSnapshot("after_withdraw_uint256_address_uint256", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.withdraw(2 * baseUnit, accountToSaveBalances)));
            comparator.takeSnapshot("after_withdraw_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.withdraw(baseUnit)));
            comparator.takeSnapshot("after_withdraw_uint256", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.withdraw()));
            comparator.takeSnapshot("after_withdraw", accountToSaveBalances);
        } else {
            IYVault vault = IYVault(vaultAddress);

            evm.prank(USER);
            vault.deposit(5 * baseUnit, accountToSaveBalances);
            comparator.takeSnapshot("after_deposit_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            vault.deposit(5 * baseUnit);
            comparator.takeSnapshot("after_deposit_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            vault.deposit();
            comparator.takeSnapshot("after_deposit", accountToSaveBalances);

            evm.prank(USER);
            vault.withdraw(3 * baseUnit, accountToSaveBalances, 10);
            comparator.takeSnapshot("after_withdraw_uint256_address_uint256", accountToSaveBalances);

            evm.prank(USER);
            vault.withdraw(2 * baseUnit, accountToSaveBalances);
            comparator.takeSnapshot("after_withdraw_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            vault.withdraw(baseUnit);
            comparator.takeSnapshot("after_withdraw_uint256", accountToSaveBalances);

            evm.prank(USER);
            vault.withdraw();
            comparator.takeSnapshot("after_withdraw", accountToSaveBalances);
        }
    }

    function openCreditAccountWithUnderlying(
        ICreditFacade creditFacade,
        address token,
        address vaultAdapter,
        uint256 accountAmount,
        uint256 mintAmount
    ) internal returns (address creditAccount) {
        tokenTestSuite.mint(token, USER, mintAmount);

        // Approve tokens
        tokenTestSuite.approve(token, USER, address(creditFacade.creditManager()));

        evm.startPrank(USER);
        creditFacade.openCreditAccountMulticall(
            accountAmount,
            USER,
            multicallBuilder(CreditFacadeMulticaller(address(creditFacade)).addCollateral(USER, token, mintAmount)),
            0
        );

        evm.stopPrank();

        creditAccount = creditFacade.creditManager().getCreditAccountOrRevert(USER);

        tokenTestSuite.alignBalances(_getTokensToTrack(vaultAdapter), creditAccount, USER);
    }

    function prepareComparator(address vaultAdapter) internal returns (BalanceComparator comparator) {
        comparator = new BalanceComparator(
            _stages,
            _getTokensToTrack(vaultAdapter),
            tokenTestSuite
        );
    }

    /// @dev [L-YET-1]: yearn adapters and original contracts work identically
    function test_live_YET_01_Yearn_adapters_and_original_contracts_are_equivalent() public liveOnly {
        (, ICreditFacade creditFacade,, uint256 accountAmount) = lts.getActiveCM();

        for (uint256 i = 0; i < yearnVaults.length; ++i) {
            uint256 snapshot0 = evm.snapshot();

            address vaultAdapter = lts.getAdapter(address(creditFacade.creditManager()), yearnVaults[i]);

            address token = IYearnV2Adapter(vaultAdapter).token();

            uint256 amountToMint = lts.priceOracle().convert(accountAmount, creditFacade.underlying(), token);

            address creditAccount =
                openCreditAccountWithUnderlying(creditFacade, token, vaultAdapter, accountAmount, amountToMint);

            uint256 snapshot1 = evm.snapshot();

            BalanceComparator comparator = prepareComparator(vaultAdapter);

            tokenTestSuite.approve(token, USER, supportedContracts.addressOf(yearnVaults[i]));

            compareBehavior(
                creditFacade,
                supportedContracts.addressOf(yearnVaults[i]),
                USER,
                10 ** IERC20Metadata(token).decimals(),
                false,
                comparator
            );

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(USER);

            evm.revertTo(snapshot1);

            comparator = prepareComparator(vaultAdapter);

            compareBehavior(
                creditFacade, vaultAdapter, creditAccount, 10 ** IERC20Metadata(token).decimals(), true, comparator
            );

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots, 2);

            evm.revertTo(snapshot0);
        }
    }
}
