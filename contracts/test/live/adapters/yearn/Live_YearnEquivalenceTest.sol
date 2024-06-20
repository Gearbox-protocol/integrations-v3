// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";

import {IYVault} from "../../../../integrations/yearn/IYVault.sol";
import {IYearnV2Adapter} from "../../../../interfaces/yearn/IYearnV2Adapter.sol";
import {YearnV2_Calls, YearnV2_Multicaller} from "../../../multicall/yearn/YearnV2_Calls.sol";
import {IAdapter} from "../../../../interfaces/IAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
import {AddressList} from "@gearbox-protocol/core-v3/contracts/test/lib/AddressList.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES
import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_YearnEquivalenceTest is LiveTestHelper {
    using YearnV2_Calls for YearnV2_Multicaller;
    using AddressList for address[];

    string[7] stages = [
        "after_deposit_uint256_address",
        "after_deposit_uint256",
        "after_deposit_diff",
        "after_withdraw_uint256_address_uint256",
        "after_withdraw_uint256_address",
        "after_withdraw_uint256",
        "after_withdraw_diff"
    ];

    string[] _stages;

    function setUp() public {
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
        address creditAccount,
        address vaultAddress,
        uint256 baseUnit,
        bool isAdapter,
        BalanceComparator comparator
    ) internal {
        address underlyingToken = IYearnV2Adapter(vaultAddress).token();
        address vaultToken = isAdapter ? IYearnV2Adapter(vaultAddress).targetContract() : vaultAddress;

        if (isAdapter) {
            YearnV2_Multicaller vault = YearnV2_Multicaller(vaultAddress);

            vm.startPrank(USER);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(vault.deposit(100 * baseUnit, creditAccount)));
            comparator.takeSnapshot("after_deposit_uint256_address", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(vault.deposit(100 * baseUnit)));
            comparator.takeSnapshot("after_deposit_uint256_address", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(vault.depositDiff(100 * baseUnit)));
            comparator.takeSnapshot("after_deposit_diff", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(vault.withdraw(50 * baseUnit, creditAccount, 10))
            );
            comparator.takeSnapshot("after_withdraw_uint256_address_uint256", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(vault.withdraw(10 * baseUnit, creditAccount)));
            comparator.takeSnapshot("after_withdraw_uint256_address", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(vault.withdraw(10 * baseUnit)));
            comparator.takeSnapshot("after_withdraw_uint256", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(vault.withdrawDiff(10 * baseUnit)));
            comparator.takeSnapshot("after_withdraw_diff", creditAccount);

            vm.stopPrank();
        } else {
            IYVault vault = IYVault(vaultAddress);

            vm.startPrank(creditAccount);

            vault.deposit(100 * baseUnit, creditAccount);
            comparator.takeSnapshot("after_deposit_uint256_address", creditAccount);

            vault.deposit(100 * baseUnit);
            comparator.takeSnapshot("after_deposit_uint256_address", creditAccount);

            uint256 remainingBalance = IERC20(underlyingToken).balanceOf(creditAccount);
            vault.deposit(remainingBalance - 100 * baseUnit);
            comparator.takeSnapshot("after_deposit_diff", creditAccount);

            vault.withdraw(50 * baseUnit, creditAccount, 10);
            comparator.takeSnapshot("after_withdraw_uint256_address_uint256", creditAccount);

            vault.withdraw(10 * baseUnit, creditAccount);
            comparator.takeSnapshot("after_withdraw_uint256_address", creditAccount);

            vault.withdraw(10 * baseUnit);
            comparator.takeSnapshot("after_withdraw_uint256", creditAccount);

            remainingBalance = IERC20(vaultToken).balanceOf(creditAccount);
            vault.withdraw(remainingBalance - 10 * baseUnit);
            comparator.takeSnapshot("after_withdraw_diff", creditAccount);

            vm.stopPrank();
        }
    }

    function openCreditAccountWithUnderlying(address token, uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        tokenTestSuite.mint(token, creditAccount, amount);
    }

    function prepareComparator(address vaultAdapter) internal returns (BalanceComparator comparator) {
        address[] memory tokensToTrack = new address[](2);

        tokensToTrack[0] = IYearnV2Adapter(vaultAdapter).token();
        tokensToTrack[1] = IYearnV2Adapter(vaultAdapter).targetContract();

        Tokens[] memory _tokensToTrack = new Tokens[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    /// @dev [L-YET-1]: yearn adapters and original contracts work identically
    function test_live_YET_01_Yearn_adapters_and_original_contracts_are_equivalent() public attachOrLiveTest {
        address[] memory adapters = creditConfigurator.allowedAdapters();

        for (uint256 i = 0; i < adapters.length; ++i) {
            if (IAdapter(adapters[i]).adapterType() != uint256(AdapterType.YEARN_V2)) continue;

            uint256 snapshot0 = vm.snapshot();

            address token = IYearnV2Adapter(adapters[i]).token();

            address creditAccount =
                openCreditAccountWithUnderlying(token, 3000 * 10 ** IERC20Metadata(token).decimals());

            tokenTestSuite.approve(token, creditAccount, IAdapter(adapters[i]).targetContract());

            uint256 snapshot1 = vm.snapshot();

            BalanceComparator comparator = prepareComparator(adapters[i]);

            compareBehavior(
                creditAccount,
                IAdapter(adapters[i]).targetContract(),
                10 ** IERC20Metadata(token).decimals(),
                false,
                comparator
            );

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot1);

            comparator = prepareComparator(adapters[i]);

            compareBehavior(creditAccount, adapters[i], 10 ** IERC20Metadata(token).decimals(), true, comparator);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots, 0);

            vm.revertTo(snapshot0);
        }
    }
}
