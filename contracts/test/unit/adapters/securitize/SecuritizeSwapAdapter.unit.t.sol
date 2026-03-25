// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {SecuritizeSwapAdapter} from "../../../../adapters/securitize/SecuritizeSwapAdapter.sol";
import {ISecuritizeSwap} from "../../../../integrations/securitize/ISecuritizeSwap.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

contract SecuritizeSwapMock is ISecuritizeSwap {
    address public immutable override dsToken;
    address public immutable override stableCoinToken;

    uint256 internal _multiplier; // dsToken per unit stableCoinAmount, returned as: stableAmount * multiplier

    constructor(address _dsToken, address _stableCoinToken, uint256 multiplier) {
        dsToken = _dsToken;
        stableCoinToken = _stableCoinToken;
        _multiplier = multiplier;
    }

    function calculateDsTokenAmount(uint256 _stableCoinAmount) external view returns (uint256) {
        return _stableCoinAmount * _multiplier;
    }

    function buy(uint256 _dsTokenAmount, uint256 _maxStableCoinAmount) external returns (uint256) {
        _dsTokenAmount;
        _maxStableCoinAmount;
        return 0;
    }
}

    /// @title Securitize Swap adapter unit test
    /// @notice U:[SSA]: Unit tests for SecuritizeSwapAdapter
    contract SecuritizeSwapAdapterUnitTest is AdapterUnitTestHelper {
        SecuritizeSwapAdapter adapter;
        SecuritizeSwapMock target;

        address dsToken;
        address stableCoinToken;
        uint256 multiplier = 2;

        function setUp() public {
            _setUp();

            dsToken = tokens[0];
            stableCoinToken = tokens[1];

            target = new SecuritizeSwapMock(dsToken, stableCoinToken, multiplier);
            adapter = new SecuritizeSwapAdapter(address(creditManager), address(target));
        }

        /// @notice U:[SSA-1]: Constructor works as expected
        function test_U_SSA_01_constructor_works_as_expected() public {
            assertEq(adapter.contractType(), "ADAPTER::SECURITIZE_SWAP");
            assertEq(adapter.version(), 3_10);

            assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
            assertEq(adapter.targetContract(), address(target), "Incorrect targetContract");
            assertEq(adapter.dsToken(), dsToken, "Incorrect dsToken");
            assertEq(adapter.stableCoinToken(), stableCoinToken, "Incorrect stableCoinToken");
        }

        /// @notice U:[SSA-2]: Wrapper functions revert on wrong caller
        function test_U_SSA_02_wrapper_functions_revert_on_wrong_caller() public {
            _revertsOnNonFacadeCaller();
            adapter.buy(1000, 2000);

            _revertsOnNonFacadeCaller();
            adapter.buyExactIn(1000);

            _revertsOnNonFacadeCaller();
            adapter.buyExactInDiff(100);
        }

        /// @notice U:[SSA-3]: `buy` works as expected
        function test_U_SSA_03_buy_works_as_expected() public {
            uint256 dsTokenAmount = 1_000;
            uint256 maxStableCoinAmount = 2_000;

            _executesSwap({
                tokenIn: stableCoinToken,
                callData: abi.encodeCall(ISecuritizeSwap.buy, (dsTokenAmount, maxStableCoinAmount)),
                requiresApproval: true
            });

            vm.prank(creditFacade);
            bool useSafePrices = adapter.buy(dsTokenAmount, maxStableCoinAmount);
            assertTrue(useSafePrices);
        }

        /// @notice U:[SSA-4]: `buyExactIn` works as expected
        function test_U_SSA_04_buyExactIn_works_as_expected() public {
            uint256 stableCoinAmount = 1_234;
            uint256 expectedDsTokenAmount = target.calculateDsTokenAmount(stableCoinAmount);

            _executesSwap({
                tokenIn: stableCoinToken,
                callData: abi.encodeCall(ISecuritizeSwap.buy, (expectedDsTokenAmount, stableCoinAmount)),
                requiresApproval: true
            });

            vm.prank(creditFacade);
            bool useSafePrices = adapter.buyExactIn(stableCoinAmount);
            assertTrue(useSafePrices);
        }

        /// @notice U:[SSA-5]: `buyExactInDiff` returns false when balance <= leftover
        function test_U_SSA_05_buyExactInDiff_returns_false_when_nothing_to_buy() public {
            deal(stableCoinToken, creditAccount, 1_000);

            vm.prank(creditFacade);
            bool useSafePrices = adapter.buyExactInDiff(1_000);
            assertFalse(useSafePrices);
        }

        /// @notice U:[SSA-6]: `buyExactInDiff` works as expected
        function test_U_SSA_06_buyExactInDiff_works_as_expected() public {
            deal(stableCoinToken, creditAccount, 2_000);
            uint256 leftoverAmount = 1_000;
            uint256 stableCoinAmount = 1_000;
            uint256 expectedDsTokenAmount = target.calculateDsTokenAmount(stableCoinAmount);

            _executesSwap({
                tokenIn: stableCoinToken,
                callData: abi.encodeCall(ISecuritizeSwap.buy, (expectedDsTokenAmount, stableCoinAmount)),
                requiresApproval: true
            });

            vm.prank(creditFacade);
            bool useSafePrices = adapter.buyExactInDiff(leftoverAmount);
            assertTrue(useSafePrices);
        }

        /// @notice U:[SSA-7]: `serialize` works as expected
        function test_U_SSA_07_serialize_works_as_expected() public {
            bytes memory serializedData = adapter.serialize();
            (address cm, address tc, address ds, address sc) =
                abi.decode(serializedData, (address, address, address, address));
            assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
            assertEq(tc, address(target), "Incorrect targetContract in serialized data");
            assertEq(ds, dsToken, "Incorrect dsToken in serialized data");
            assertEq(sc, stableCoinToken, "Incorrect stableCoinToken in serialized data");
        }
    }

