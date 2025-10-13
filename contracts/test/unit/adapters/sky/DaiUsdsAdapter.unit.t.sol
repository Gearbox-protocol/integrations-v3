// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {DaiUsdsAdapter} from "../../../../adapters/sky/DaiUsdsAdapter.sol";
import {IDaiUsds} from "../../../../integrations/sky/IDaiUsds.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title DaiUsds adapter unit test
/// @notice U:[DUSDS]: Unit tests for DAI/USDS adapter
contract DaiUsdsAdapterUnitTest is AdapterUnitTestHelper {
    DaiUsdsAdapter adapter;

    address dai;
    address usds;
    address daiUsdsExchange;

    function setUp() public {
        _setUp();

        dai = tokens[0];
        usds = tokens[1];
        daiUsdsExchange = tokens[2];

        vm.mockCall(daiUsdsExchange, abi.encodeCall(IDaiUsds.dai, ()), abi.encode(dai));
        vm.mockCall(daiUsdsExchange, abi.encodeCall(IDaiUsds.usds, ()), abi.encode(usds));

        adapter = new DaiUsdsAdapter(address(creditManager), daiUsdsExchange);
    }

    /// @notice U:[DUSDS-1]: Constructor works as expected
    function test_U_DUSDS_01_constructor_works_as_expected() public {
        _readsTokenMask(dai);
        _readsTokenMask(usds);
        adapter = new DaiUsdsAdapter(address(creditManager), daiUsdsExchange);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), daiUsdsExchange, "Incorrect targetContract");
        assertEq(adapter.dai(), dai, "Incorrect dai");
        assertEq(adapter.usds(), usds, "Incorrect usds");
    }

    /// @notice U:[DUSDS-2]: Wrapper functions revert on wrong caller
    function test_U_DUSDS_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.daiToUsds(address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.daiToUsdsDiff(0);

        _revertsOnNonFacadeCaller();
        adapter.usdsToDai(address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.usdsToDaiDiff(0);
    }

    /// @notice U:[DUSDS-3]: `daiToUsds()` works as expected
    function test_U_DUSDS_03_daiToUsds_works_as_expected() public {
        uint256 amount = 1000;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: dai,
            callData: abi.encodeCall(IDaiUsds.daiToUsds, (creditAccount, amount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.daiToUsds(address(0), amount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[DUSDS-4]: `daiToUsdsDiff()` works as expected
    function test_U_DUSDS_04_daiToUsdsDiff_works_as_expected() public diffTestCases {
        deal({token: dai, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: dai,
            callData: abi.encodeCall(IDaiUsds.daiToUsds, (creditAccount, diffInputAmount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.daiToUsdsDiff(diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[DUSDS-5]: `usdsToDai()` works as expected
    function test_U_DUSDS_05_usdsToDai_works_as_expected() public {
        uint256 amount = 1000;

        _readsActiveAccount();
        _executesSwap({
            tokenIn: usds,
            callData: abi.encodeCall(IDaiUsds.usdsToDai, (creditAccount, amount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.usdsToDai(address(0), amount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[DUSDS-6]: `usdsToDaiDiff()` works as expected
    function test_U_DUSDS_06_usdsToDaiDiff_works_as_expected() public diffTestCases {
        deal({token: usds, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: usds,
            callData: abi.encodeCall(IDaiUsds.usdsToDai, (creditAccount, diffInputAmount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.usdsToDaiDiff(diffLeftoverAmount);
        assertFalse(useSafePrices);
    }
}
