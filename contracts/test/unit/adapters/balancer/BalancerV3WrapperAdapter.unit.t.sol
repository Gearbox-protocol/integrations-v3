// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {BalancerV3WrapperAdapter} from "../../../../adapters/balancer/BalancerV3WrapperAdapter.sol";
import {IBalancerV3Wrapper} from "../../../../integrations/balancer/IBalancerV3Wrapper.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Balancer V3 Wrapper adapter unit test
/// @notice U:[BV3W]: Unit tests for Balancer V3 Wrapper adapter
contract BalancerV3WrapperAdapterUnitTest is AdapterUnitTestHelper {
    BalancerV3WrapperAdapter adapter;

    address balancerPoolToken;
    address wrapper;

    function setUp() public {
        _setUp();

        balancerPoolToken = tokens[0];
        wrapper = tokens[1];

        vm.mockCall(wrapper, abi.encodeCall(IBalancerV3Wrapper.balancerPoolToken, ()), abi.encode(balancerPoolToken));

        adapter = new BalancerV3WrapperAdapter(address(creditManager), wrapper);
    }

    /// @notice U:[BV3W-1]: Constructor works as expected
    function test_U_BV3W_01_constructor_works_as_expected() public {
        _readsTokenMask(balancerPoolToken);
        _readsTokenMask(wrapper);
        adapter = new BalancerV3WrapperAdapter(address(creditManager), wrapper);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), wrapper, "Incorrect targetContract");
        assertEq(adapter.balancerPoolToken(), balancerPoolToken, "Incorrect balancerPoolToken");
    }

    /// @notice U:[BV3W-2]: Wrapper functions revert on wrong caller
    function test_U_BV3W_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.mint(0);

        _revertsOnNonFacadeCaller();
        adapter.mintDiff(0);

        _revertsOnNonFacadeCaller();
        adapter.burn(0);

        _revertsOnNonFacadeCaller();
        adapter.burnDiff(0);
    }

    /// @notice U:[BV3W-3]: `mint()` works as expected
    function test_U_BV3W_03_mint_works_as_expected() public {
        _executesSwap({
            tokenIn: balancerPoolToken,
            callData: abi.encodeCall(IBalancerV3Wrapper.mint, (1000)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.mint(1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[BV3W-4]: `mintDiff()` works as expected
    function test_U_BV3W_04_mintDiff_works_as_expected() public diffTestCases {
        deal({token: balancerPoolToken, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: balancerPoolToken,
            callData: abi.encodeCall(IBalancerV3Wrapper.mint, (diffInputAmount)),
            requiresApproval: true
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.mintDiff(diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[BV3W-5]: `burn()` works as expected
    function test_U_BV3W_05_burn_works_as_expected() public {
        _executesSwap({
            tokenIn: wrapper,
            callData: abi.encodeCall(IBalancerV3Wrapper.burn, (1000)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.burn(1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[BV3W-6]: `burnDiff()` works as expected
    function test_U_BV3W_06_burnDiff_works_as_expected() public diffTestCases {
        deal({token: wrapper, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: wrapper,
            callData: abi.encodeCall(IBalancerV3Wrapper.burn, (diffInputAmount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.burnDiff(diffLeftoverAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[BV3W-7]: `serialize()` works as expected
    function test_U_BV3W_07_serialize_works_as_expected() public {
        bytes memory serialized = adapter.serialize();
        (address cm, address tc, address bpt) = abi.decode(serialized, (address, address, address));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, wrapper, "Incorrect targetContract in serialized data");
        assertEq(bpt, balancerPoolToken, "Incorrect balancerPoolToken in serialized data");
    }
}
