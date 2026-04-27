// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {SecuritizeOnRampAdapter} from "../../../../adapters/securitize/SecuritizeOnRampAdapter.sol";
import {ISecuritizeOnRamp} from "../../../../integrations/securitize/ISecuritizeOnRamp.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

contract SecuritizeOnRampMock is ISecuritizeOnRamp {
    address public immutable override dsToken;
    address public immutable override liquidityToken;

    constructor(address _dsToken, address _liquidityToken) {
        dsToken = _dsToken;
        liquidityToken = _liquidityToken;
    }

    function swap(uint256 _liquidityAmount, uint256 _minOutAmount) external {
        _liquidityAmount;
        _minOutAmount;
    }

    function calculateDsTokenAmount(uint256 _liquidityAmount)
        external
        view
        returns (uint256 dsTokenAmount, uint256 rate, uint256 fee)
    {
        dsTokenAmount = _liquidityAmount;
        rate = 0;
        fee = 0;
    }

    function navProvider() external view returns (address) {
        return address(0);
    }
}

    /// @title Securitize On-Ramp Adapter unit test
    /// @notice U:[SOR]: Unit tests for SecuritizeOnRampAdapter
    contract SecuritizeOnRampAdapterUnitTest is AdapterUnitTestHelper {
        SecuritizeOnRampAdapter adapter;
        SecuritizeOnRampMock onRamp;

        address dsToken;
        address liquidityToken;

        function setUp() public {
            _setUp();

            dsToken = tokens[0];
            liquidityToken = tokens[1];

            onRamp = new SecuritizeOnRampMock(dsToken, liquidityToken);
            adapter = new SecuritizeOnRampAdapter(address(creditManager), address(onRamp));
        }

        /// @notice U:[SOR-1]: Constructor works as expected
        function test_U_SOR_01_constructor_works_as_expected() public {
            _readsTokenMask(dsToken);
            _readsTokenMask(liquidityToken);

            adapter = new SecuritizeOnRampAdapter(address(creditManager), address(onRamp));

            assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
            assertEq(adapter.targetContract(), address(onRamp), "Incorrect targetContract");
            assertEq(adapter.dsToken(), dsToken, "Incorrect dsToken");
            assertEq(adapter.liquidityToken(), liquidityToken, "Incorrect liquidityToken");
        }

        /// @notice U:[SOR-2]: Wrapper functions revert on wrong caller
        function test_U_SOR_02_wrapper_functions_revert_on_wrong_caller() public {
            _revertsOnNonFacadeCaller();
            adapter.swap(1000, 900);

            _revertsOnNonFacadeCaller();
            adapter.swapDiff(100, 2 * RAY);
        }

        /// @notice U:[SOR-3]: `swap` works as expected
        function test_U_SOR_03_swap_works_as_expected() public {
            uint256 liquidityAmount = 1_000;
            uint256 minOutAmount = 900;

            _executesSwap({
                tokenIn: liquidityToken,
                callData: abi.encodeCall(ISecuritizeOnRamp.swap, (liquidityAmount, minOutAmount)),
                requiresApproval: true
            });

            vm.prank(creditFacade);
            bool useSafePrices = adapter.swap(liquidityAmount, minOutAmount);
            assertTrue(useSafePrices);
        }

        /// @notice U:[SOR-4]: `swapDiff` returns false when balance <= leftover
        function test_U_SOR_04_swapDiff_returns_false_when_nothing_to_swap() public {
            uint256 stableCoinBalance = 1_000;
            uint256 leftoverAmount = 1_000;

            deal(liquidityToken, creditAccount, stableCoinBalance);

            vm.prank(creditFacade);
            bool useSafePrices = adapter.swapDiff(leftoverAmount, 2 * RAY);
            assertFalse(useSafePrices);
        }

        /// @notice U:[SOR-5]: `swapDiff` works as expected
        function test_U_SOR_05_swapDiff_works_as_expected() public {
            uint256 stableCoinBalance = 1_000;
            uint256 leftoverAmount = 100;
            uint256 liquidityAmount = stableCoinBalance - leftoverAmount; // 900
            uint256 rateMinRAY = 2 * RAY; // 2.0
            uint256 minOutAmount = (liquidityAmount * rateMinRAY) / RAY; // 1800

            deal(liquidityToken, creditAccount, stableCoinBalance);

            _executesSwap({
                tokenIn: liquidityToken,
                callData: abi.encodeCall(ISecuritizeOnRamp.swap, (liquidityAmount, minOutAmount)),
                requiresApproval: true
            });

            vm.prank(creditFacade);
            bool useSafePrices = adapter.swapDiff(leftoverAmount, rateMinRAY);
            assertTrue(useSafePrices);
        }

        /// @notice U:[SOR-6]: `serialize` works as expected
        function test_U_SOR_06_serialize_works_as_expected() public {
            bytes memory serializedData = adapter.serialize();

            (address cm, address tc, address ds, address sc) =
                abi.decode(serializedData, (address, address, address, address));
            assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
            assertEq(tc, address(onRamp), "Incorrect targetContract in serialized data");
            assertEq(ds, dsToken, "Incorrect dsToken in serialized data");
            assertEq(sc, liquidityToken, "Incorrect liquidityToken in serialized data");
        }
    }

