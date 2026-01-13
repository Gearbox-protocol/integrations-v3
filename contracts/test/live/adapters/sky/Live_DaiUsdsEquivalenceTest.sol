// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";

import {IDaiUsds} from "../../../../integrations/sky/IDaiUsds.sol";
import {IDaiUsdsAdapter} from "../../../../interfaces/sky/IDaiUsdsAdapter.sol";
import {DaiUsds_Calls, DaiUsds_Multicaller} from "../../../multicall/sky/DaiUsds_Calls.sol";
import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

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

contract Live_DaiUsdsEquivalenceTest is LiveTestHelper {
    using DaiUsds_Calls for DaiUsds_Multicaller;
    using AddressList for address[];

    string[4] stages = ["after_daiToUsds", "after_daiToUsdsDiff", "after_usdsToDai", "after_usdsToDaiDiff"];

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
        address daiUsdsAddress,
        uint256 baseUnit,
        bool isAdapter,
        BalanceComparator comparator
    ) internal {
        address dai = IDaiUsdsAdapter(daiUsdsAddress).dai();
        address usds = IDaiUsdsAdapter(daiUsdsAddress).usds();

        if (isAdapter) {
            DaiUsds_Multicaller daiUsds = DaiUsds_Multicaller(daiUsdsAddress);

            vm.startPrank(USER);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(daiUsds.daiToUsds(creditAccount, 100 * baseUnit))
            );
            comparator.takeSnapshot("after_daiToUsds", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(daiUsds.daiToUsdsDiff(100 * baseUnit)));
            comparator.takeSnapshot("after_daiToUsdsDiff", creditAccount);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(daiUsds.usdsToDai(creditAccount, 50 * baseUnit))
            );
            comparator.takeSnapshot("after_usdsToDai", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(daiUsds.usdsToDaiDiff(10 * baseUnit)));
            comparator.takeSnapshot("after_usdsToDaiDiff", creditAccount);

            vm.stopPrank();
        } else {
            IDaiUsds daiUsds = IDaiUsds(daiUsdsAddress);

            vm.startPrank(creditAccount);

            daiUsds.daiToUsds(creditAccount, 100 * baseUnit);
            comparator.takeSnapshot("after_daiToUsds", creditAccount);

            uint256 remainingDaiBalance = IERC20(dai).balanceOf(creditAccount);
            daiUsds.daiToUsds(creditAccount, remainingDaiBalance - 100 * baseUnit);
            comparator.takeSnapshot("after_daiToUsdsDiff", creditAccount);

            daiUsds.usdsToDai(creditAccount, 50 * baseUnit);
            comparator.takeSnapshot("after_usdsToDai", creditAccount);

            uint256 remainingUsdsBalance = IERC20(usds).balanceOf(creditAccount);
            daiUsds.usdsToDai(creditAccount, remainingUsdsBalance - 10 * baseUnit);
            comparator.takeSnapshot("after_usdsToDaiDiff", creditAccount);

            vm.stopPrank();
        }
    }

    function openCreditAccountWithDai(address daiUsdsAdapter, uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        address dai = IDaiUsdsAdapter(daiUsdsAdapter).dai();
        tokenTestSuite.mint(dai, creditAccount, amount);
    }

    function prepareComparator(address daiUsdsAdapter) internal returns (BalanceComparator comparator) {
        address[] memory tokensToTrack = new address[](2);

        tokensToTrack[0] = IDaiUsdsAdapter(daiUsdsAdapter).dai();
        tokensToTrack[1] = IDaiUsdsAdapter(daiUsdsAdapter).usds();

        uint256[] memory _tokensToTrack = new uint256[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    /// @dev [L-DUSDS-1]: DaiUsds adapters and original contracts work identically
    function test_live_DUSDS_01_DaiUsds_adapters_and_original_contracts_are_equivalent() public attachOrLiveTest {
        address[] memory adapters = creditConfigurator.allowedAdapters();

        for (uint256 i = 0; i < adapters.length; ++i) {
            if (IAdapter(adapters[i]).contractType() != "ADAPTER::DAI_USDS_EXCHANGE") continue;

            uint256 snapshot0 = vm.snapshotState();

            address dai = IDaiUsdsAdapter(adapters[i]).dai();
            address usds = IDaiUsdsAdapter(adapters[i]).usds();

            address creditAccount = openCreditAccountWithDai(adapters[i], 3000 * 10 ** IERC20Metadata(dai).decimals());

            tokenTestSuite.approve(dai, creditAccount, IAdapter(adapters[i]).targetContract());
            tokenTestSuite.approve(usds, creditAccount, IAdapter(adapters[i]).targetContract());

            uint256 snapshot1 = vm.snapshotState();

            BalanceComparator comparator = prepareComparator(adapters[i]);

            compareBehavior(
                creditAccount,
                IAdapter(adapters[i]).targetContract(),
                10 ** IERC20Metadata(dai).decimals(),
                false,
                comparator
            );

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertToState(snapshot1);

            comparator = prepareComparator(adapters[i]);

            compareBehavior(creditAccount, adapters[i], 10 ** IERC20Metadata(dai).decimals(), true, comparator);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots, 0);

            vm.revertToState(snapshot0);
        }
    }
}
