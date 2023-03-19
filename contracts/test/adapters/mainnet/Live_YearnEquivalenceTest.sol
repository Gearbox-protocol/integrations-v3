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

    /// HELPER

    function compareBehavior(
        address vaultAddress,
        address accountToSaveBalances,
        uint256 baseUnit,
        bool isAdapter,
        BalanceComparator comparator
    ) internal {
        if (isAdapter) {
            ICreditFacade creditFacade = lts.creditFacades(Tokens.DAI);
            YearnV2_Multicaller vault = YearnV2_Multicaller(vaultAddress);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.deposit(100 * baseUnit, accountToSaveBalances)));
            comparator.takeSnapshot("after_deposit_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.deposit(100 * baseUnit)));
            comparator.takeSnapshot("after_deposit_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.deposit()));
            comparator.takeSnapshot("after_deposit", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.withdraw(50 * baseUnit, accountToSaveBalances, 10)));
            comparator.takeSnapshot("after_withdraw_uint256_address_uint256", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.withdraw(10 * baseUnit, accountToSaveBalances)));
            comparator.takeSnapshot("after_withdraw_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.withdraw(10 * baseUnit)));
            comparator.takeSnapshot("after_withdraw_uint256", accountToSaveBalances);

            evm.prank(USER);
            creditFacade.multicall(multicallBuilder(vault.withdraw()));
            comparator.takeSnapshot("after_withdraw", accountToSaveBalances);
        } else {
            IYVault vault = IYVault(vaultAddress);

            evm.prank(USER);
            vault.deposit(100 * baseUnit, accountToSaveBalances);
            comparator.takeSnapshot("after_deposit_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            vault.deposit(100 * baseUnit);
            comparator.takeSnapshot("after_deposit_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            vault.deposit();
            comparator.takeSnapshot("after_deposit", accountToSaveBalances);

            evm.prank(USER);
            vault.withdraw(50 * baseUnit, accountToSaveBalances, 10);
            comparator.takeSnapshot("after_withdraw_uint256_address_uint256", accountToSaveBalances);

            evm.prank(USER);
            vault.withdraw(10 * baseUnit, accountToSaveBalances);
            comparator.takeSnapshot("after_withdraw_uint256_address", accountToSaveBalances);

            evm.prank(USER);
            vault.withdraw(10 * baseUnit);
            comparator.takeSnapshot("after_withdraw_uint256", accountToSaveBalances);

            evm.prank(USER);
            vault.withdraw();
            comparator.takeSnapshot("after_withdraw", accountToSaveBalances);
        }
    }

    function openCreditAccountWithUnderlying(address token, uint256 amount) internal returns (address creditAccount) {
        ICreditFacade creditFacade = lts.creditFacades(Tokens.DAI);

        (uint256 minAmount,) = creditFacade.limits();

        tokenTestSuite.mint(Tokens.DAI, USER, minAmount);

        // Approve tokens
        tokenTestSuite.approve(Tokens.DAI, USER, address(lts.creditManagers(Tokens.DAI)));

        evm.startPrank(USER);
        creditFacade.openCreditAccountMulticall(
            minAmount,
            USER,
            multicallBuilder(
                CreditFacadeMulticaller(address(creditFacade)).addCollateral(
                    USER, tokenTestSuite.addressOf(Tokens.DAI), minAmount
                )
            ),
            0
        );

        evm.stopPrank();

        creditAccount = lts.creditManagers(Tokens.DAI).getCreditAccountOrRevert(USER);

        if (token != tokenTestSuite.addressOf(Tokens.DAI)) {
            tokenTestSuite.mint(token, creditAccount, amount);
        }
    }

    function prepareComparator(address vaultAdapter) internal returns (BalanceComparator comparator) {
        address[] memory tokensToTrack = new address[](2);

        tokensToTrack[0] = IYearnV2Adapter(vaultAdapter).token();
        tokensToTrack[1] = IYearnV2Adapter(vaultAdapter).targetContract();

        Tokens[] memory _tokensToTrack = new Tokens[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(
            _stages,
            _tokensToTrack,
            tokenTestSuite
        );
    }

    /// @dev [L-YET-1]: yearn adapters and original contracts work identically
    function test_live_YET_01_Yearn_adapters_and_original_contracts_are_equivalent() public liveOnly {
        for (uint256 i = 0; i < yearnVaults.length; ++i) {
            uint256 snapshot0 = evm.snapshot();
            uint256 snapshot1 = evm.snapshot();

            address vaultAdapter = lts.getAdapter(Tokens.DAI, yearnVaults[i]);

            address token = IYearnV2Adapter(vaultAdapter).token();

            BalanceComparator comparator = prepareComparator(vaultAdapter);

            tokenTestSuite.approve(token, USER, supportedContracts.addressOf(yearnVaults[i]));

            ICreditFacade creditFacade = lts.creditFacades(Tokens.DAI);

            (uint256 minAmount,) = creditFacade.limits();

            tokenTestSuite.mint(
                token,
                USER,
                yearnVaults[i] == Contracts.YEARN_DAI_VAULT
                    ? minAmount * 2
                    : 3000 * 10 ** IERC20Metadata(token).decimals()
            );

            compareBehavior(
                supportedContracts.addressOf(yearnVaults[i]),
                USER,
                10 ** IERC20Metadata(token).decimals(),
                false,
                comparator
            );

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(USER);

            evm.revertTo(snapshot1);

            comparator = prepareComparator(vaultAdapter);

            address creditAccount =
                openCreditAccountWithUnderlying(token, 3000 * 10 ** IERC20Metadata(token).decimals());

            compareBehavior(
                lts.getAdapter(Tokens.DAI, yearnVaults[i]),
                creditAccount,
                10 ** IERC20Metadata(token).decimals(),
                true,
                comparator
            );

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots, 1);

            evm.revertTo(snapshot0);
        }
    }
}
