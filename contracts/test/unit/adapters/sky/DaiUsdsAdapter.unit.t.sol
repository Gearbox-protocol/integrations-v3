// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {DaiUsdsAdapter} from "../../../../adapters/sky/DaiUsdsAdapter.sol";
import {IDaiUsds} from "../../../../integrations/sky/IDaiUsds.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title DAI/USDS adapter unit test
/// @notice U:[DUSDS]: Unit tests for DAI/USDS adapter
contract DaiUsdsAdapterUnitTest is AdapterUnitTestHelper {
    DaiUsdsAdapter adapter;

    address dai;
    address usds;
    address daiUsdsExchange;

    uint256 daiMask;
    uint256 usdsMask;

    function setUp() public {
        _setUp();

        (dai, daiMask) = (tokens[0], 1);
        (usds, usdsMask) = (tokens[1], 2);
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
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), daiUsdsExchange, "Incorrect targetContract");
        assertEq(adapter.dai(), dai, "Incorrect dai");
        assertEq(adapter.usds(), usds, "Incorrect usds");
        assertEq(adapter.daiMask(), daiMask, "Incorrect daiMask");
        assertEq(adapter.usdsMask(), usdsMask, "Incorrect usdsMask");
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

    /// @notice U:[DUSDS-3]: `daiToUsds` works as expected
    function test_U_DUSDS_03_daiToUsds_works_as_expected() public {
        _executesSwap({
            tokenIn: dai,
            tokenOut: usds,
            callData: abi.encodeCall(IDaiUsds.daiToUsds, (creditAccount, 1000)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.daiToUsds(address(0), 1000);

        assertEq(tokensToEnable, usdsMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[DUSDS-4]: `daiToUsdsDiff` works as expected
    function test_U_DUSDS_04_daiToUsdsDiff_works_as_expected() public diffTestCases {
        deal({token: dai, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: dai,
            tokenOut: usds,
            callData: abi.encodeCall(IDaiUsds.daiToUsds, (creditAccount, diffInputAmount)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.daiToUsdsDiff(diffLeftoverAmount);

        assertEq(tokensToEnable, usdsMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? daiMask : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[DUSDS-5]: `usdsToDai` works as expected
    function test_U_DUSDS_05_usdsToDai_works_as_expected() public {
        _executesSwap({
            tokenIn: usds,
            tokenOut: dai,
            callData: abi.encodeCall(IDaiUsds.usdsToDai, (creditAccount, 1000)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.usdsToDai(address(0), 1000);

        assertEq(tokensToEnable, daiMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[DUSDS-6]: `usdsToDaiDiff` works as expected
    function test_U_DUSDS_06_usdsToDaiDiff_works_as_expected() public diffTestCases {
        deal({token: usds, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: usds,
            tokenOut: dai,
            callData: abi.encodeCall(IDaiUsds.usdsToDai, (creditAccount, diffInputAmount)),
            requiresApproval: true,
            validatesTokens: false
        });
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.usdsToDaiDiff(diffLeftoverAmount);

        assertEq(tokensToEnable, daiMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? usdsMask : 0, "Incorrect tokensToDisable");
    }
}
