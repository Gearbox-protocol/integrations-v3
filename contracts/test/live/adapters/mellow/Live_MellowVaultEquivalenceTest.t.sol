// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {IMellowVault} from "../../../../integrations/mellow/IMellowVault.sol";
import {IMellowVaultAdapter} from "../../../../interfaces/mellow/IMellowVaultAdapter.sol";
import {MellowVault_Calls, MellowVault_Multicaller} from "../../../multicall/mellow/MellowVault_Calls.sol";

import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
import {AddressList} from "@gearbox-protocol/core-v3/contracts/test/lib/AddressList.sol";

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

contract Live_MellowVaultAdapterTest is LiveTestHelper {
    using MellowVault_Calls for MellowVault_Multicaller;
    using AddressList for address[];

    BalanceComparator comparator;

    string[3] stages = ["after_deposit", "after_depositOneAsset", "after_depositOneAssetDiff"];

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

    function compareBehavior(address creditAccount, address vaultAddress, address[] memory underlyings, bool isAdapter)
        internal
    {
        uint256[] memory amounts = new uint256[](underlyings.length);
        for (uint256 i = 0; i < underlyings.length; i++) {
            amounts[i] = 100 * 10 ** IERC20Metadata(underlyings[i]).decimals();
        }

        if (isAdapter) {
            MellowVault_Multicaller vault = MellowVault_Multicaller(vaultAddress);

            vm.startPrank(USER);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(vault.deposit(creditAccount, amounts, 0, block.timestamp + 3600))
            );
            comparator.takeSnapshot("after_deposit", creditAccount);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(vault.depositOneAsset(underlyings[0], amounts[0], 0, block.timestamp + 3600))
            );
            comparator.takeSnapshot("after_depositOneAsset", creditAccount);

            uint256 leftoverAmount = 10 * 10 ** IERC20Metadata(underlyings[0]).decimals();
            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(
                    vault.depositOneAssetDiff(underlyings[0], leftoverAmount, 0, block.timestamp + 3600)
                )
            );
            comparator.takeSnapshot("after_depositOneAssetDiff", creditAccount);
        } else {
            IMellowVault vault = IMellowVault(vaultAddress);

            vm.startPrank(creditAccount);

            vault.deposit(creditAccount, amounts, 0, block.timestamp + 3600);
            comparator.takeSnapshot("after_deposit", creditAccount);

            uint256[] memory oneAssetAmounts = new uint256[](underlyings.length);
            oneAssetAmounts[0] = amounts[0];
            vault.deposit(creditAccount, oneAssetAmounts, 0, block.timestamp + 3600);
            comparator.takeSnapshot("after_depositOneAsset", creditAccount);

            uint256 leftoverAmount = 10 * 10 ** IERC20Metadata(underlyings[0]).decimals();
            uint256 amountToDeposit = IERC20(underlyings[0]).balanceOf(creditAccount) - leftoverAmount;
            oneAssetAmounts[0] = amountToDeposit;
            vault.deposit(creditAccount, oneAssetAmounts, 0, block.timestamp + 3600);
            comparator.takeSnapshot("after_depositOneAssetDiff", creditAccount);
        }

        vm.stopPrank();
    }

    function openCreditAccountWithTokens(address[] memory tokens, address mellowVault)
        internal
        returns (address creditAccount)
    {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        for (uint256 i = 0; i < tokens.length; i++) {
            tokenTestSuite.mint(tokens[i], creditAccount, 1000 * 10 ** IERC20Metadata(tokens[i]).decimals());
            tokenTestSuite.approve(tokens[i], creditAccount, address(mellowVault));
        }
    }

    function prepareComparator(address mellowVaultAdapter, address[] memory underlyings) internal {
        address[] memory tokensToTrack = new address[](underlyings.length + 1);
        tokensToTrack[0] = IAdapter(mellowVaultAdapter).targetContract();
        for (uint256 i = 0; i < underlyings.length; i++) {
            tokensToTrack[i + 1] = underlyings[i];
        }

        uint256[] memory _tokensToTrack = new uint256[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; j++) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    /// @dev [L-MEL-1]: Mellow vault adapters and original contracts work identically
    function test_live_MEL_01_Mellow_adapters_and_original_contracts_are_equivalent() public attachOrLiveTest {
        address[] memory adapters = creditConfigurator.allowedAdapters();

        for (uint256 i = 0; i < adapters.length; ++i) {
            if (IAdapter(adapters[i]).contractType() != "ADAPTER::MELLOW_LRT_VAULT") continue;

            uint256 snapshot0 = vm.snapshot();

            address mellowVault = IAdapter(adapters[i]).targetContract();
            address[] memory underlyings = IMellowVault(mellowVault).underlyingTokens();

            address creditAccount = openCreditAccountWithTokens(underlyings, mellowVault);

            uint256 snapshot1 = vm.snapshot();

            prepareComparator(adapters[i], underlyings);

            compareBehavior(creditAccount, mellowVault, underlyings, false);

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot1);

            prepareComparator(adapters[i], underlyings);

            compareBehavior(creditAccount, adapters[i], underlyings, true);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots, 0);

            vm.revertTo(snapshot0);
        }
    }
}
