// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC4626Adapter} from "../../../../interfaces/erc4626/IERC4626Adapter.sol";
import {ERC4626_Calls, ERC4626_Multicaller} from "../../../multicall/erc4626/ERC4626_Calls.sol";

import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
import {AddressList} from "@gearbox-protocol/core-v3/contracts/test/lib/AddressList.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES
import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_ERC4626EquivalenceTest is LiveTestHelper {
    using ERC4626_Calls for ERC4626_Multicaller;
    using AddressList for address[];

    Contracts[1] withdrawalExceptions = [Contracts.STAKED_USDE_VAULT];

    string[7] stages =
        ["after_deposit", "after_depositDiff", "after_mint", "after_withdraw", "after_redeem", "after_redeemDiff"];

    string[] _stages;

    function setUp() public {
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
        address underlyingToken = IERC4626Adapter(vaultAddress).asset();
        address vaultToken = isAdapter ? IERC4626Adapter(vaultAddress).targetContract() : vaultAddress;
        bool checkWithdrawals = !isWithdrawalException(vaultToken);

        if (isAdapter) {
            ERC4626_Multicaller vault = ERC4626_Multicaller(vaultAddress);

            vm.startPrank(USER);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(vault.deposit(100 * baseUnit, creditAccount)));
            comparator.takeSnapshot("after_deposit", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(vault.depositDiff(1000 * baseUnit)));
            comparator.takeSnapshot("after_depositDiff", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(vault.mint(100 * baseUnit, creditAccount)));
            comparator.takeSnapshot("after_mint", creditAccount);

            if (checkWithdrawals) {
                creditFacade.multicall(
                    creditAccount, MultiCallBuilder.build(vault.withdraw(50 * baseUnit, creditAccount, creditAccount))
                );
                comparator.takeSnapshot("after_withdraw", creditAccount);

                creditFacade.multicall(
                    creditAccount, MultiCallBuilder.build(vault.redeem(10 * baseUnit, creditAccount, creditAccount))
                );
                comparator.takeSnapshot("after_redeem", creditAccount);

                creditFacade.multicall(creditAccount, MultiCallBuilder.build(vault.redeemDiff(10 * baseUnit)));
                comparator.takeSnapshot("after_redeemDiff", creditAccount);
            }

            vm.stopPrank();
        } else {
            IERC4626 vault = IERC4626(vaultAddress);

            vm.startPrank(creditAccount);

            vault.deposit(100 * baseUnit, creditAccount);
            comparator.takeSnapshot("after_deposit", creditAccount);

            uint256 remainingBalance = IERC20(underlyingToken).balanceOf(creditAccount);
            vault.deposit(remainingBalance - 1000 * baseUnit, creditAccount);
            comparator.takeSnapshot("after_depositDiff", creditAccount);

            vault.mint(100 * baseUnit, creditAccount);
            comparator.takeSnapshot("after_mint", creditAccount);

            if (checkWithdrawals) {
                vault.withdraw(50 * baseUnit, creditAccount, creditAccount);
                comparator.takeSnapshot("after_withdraw", creditAccount);

                vault.redeem(10 * baseUnit, creditAccount, creditAccount);
                comparator.takeSnapshot("after_redeem", creditAccount);

                remainingBalance = IERC20(vaultToken).balanceOf(creditAccount);
                vault.redeem(remainingBalance - 10 * baseUnit, creditAccount, creditAccount);
                comparator.takeSnapshot("after_redeemDiff", creditAccount);
            }

            vm.stopPrank();
        }
    }

    function isWithdrawalException(address vault) internal view returns (bool) {
        for (uint256 i; i < withdrawalExceptions.length; ++i) {
            if (vault == supportedContracts.addressOf(withdrawalExceptions[i])) return true;
        }

        return false;
    }

    function openCreditAccountWithUnderlying(address token, uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        tokenTestSuite.mint(token, creditAccount, amount);
    }

    function prepareComparator(address vaultAdapter) internal returns (BalanceComparator comparator) {
        address[] memory tokensToTrack = new address[](2);

        tokensToTrack[0] = IERC4626Adapter(vaultAdapter).asset();
        tokensToTrack[1] = IERC4626Adapter(vaultAdapter).targetContract();

        uint256[] memory _tokensToTrack = new uint256[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    /// @dev [L-4626ET-1]: ERC4626 adapters and original contracts work identically
    function test_live_4626ET_01_ERC4626_adapters_and_original_contracts_are_equivalent() public attachOrLiveTest {
        address[] memory adapters = creditConfigurator.allowedAdapters();

        for (uint256 i = 0; i < adapters.length; ++i) {
            if (IAdapter(adapters[i]).contractType() != "AD_ERC4626_VAULT") continue;

            uint256 snapshot0 = vm.snapshot();

            address asset = IERC4626Adapter(adapters[i]).asset();

            address creditAccount =
                openCreditAccountWithUnderlying(asset, 3000 * 10 ** IERC20Metadata(asset).decimals());

            tokenTestSuite.approve(asset, creditAccount, IAdapter(adapters[i]).targetContract());

            uint256 snapshot1 = vm.snapshot();

            BalanceComparator comparator = prepareComparator(adapters[i]);

            compareBehavior(
                creditAccount,
                IAdapter(adapters[i]).targetContract(),
                10 ** IERC20Metadata(asset).decimals(),
                false,
                comparator
            );

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot1);

            comparator = prepareComparator(adapters[i]);

            compareBehavior(creditAccount, adapters[i], 10 ** IERC20Metadata(asset).decimals(), true, comparator);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots, 0);

            vm.revertTo(snapshot0);
        }
    }
}
