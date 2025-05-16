// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Mellow4626VaultAdapter} from "../../../../adapters/mellow/Mellow4626VaultAdapter.sol";
import {IMellowSimpleLRTVault} from "../../../../integrations/mellow/IMellowSimpleLRTVault.sol";
import {IMellow4626VaultAdapter} from "../../../../interfaces/mellow/IMellow4626VaultAdapter.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Mellow4626Vault adapter unit test
/// @notice U:[MV]: Unit tests for Mellow4626Vault adapter
contract Mellow4626VaultAdapterUnitTest is AdapterUnitTestHelper {
    Mellow4626VaultAdapter adapter;

    address vault;
    address asset;
    address stakedPhantomToken;

    function setUp() public {
        _setUp();

        asset = tokens[0];
        vault = tokens[1];
        stakedPhantomToken = tokens[2];

        vm.mockCall(vault, abi.encodeCall(IERC4626.asset, ()), abi.encode(asset));

        adapter = new Mellow4626VaultAdapter(address(creditManager), vault, stakedPhantomToken);
    }

    /// @notice U:[MV-1]: Constructor works as expected
    function test_U_MV_01_constructor_works_as_expected() public {
        _readsTokenMask(asset);
        _readsTokenMask(vault);
        _readsTokenMask(stakedPhantomToken);

        adapter = new Mellow4626VaultAdapter(address(creditManager), vault, stakedPhantomToken);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), vault, "Incorrect targetContract");
        assertEq(adapter.asset(), asset, "Incorrect asset");
        assertEq(adapter.stakedPhantomToken(), stakedPhantomToken, "Incorrect stakedPhantomToken");
    }

    /// @notice U:[MV-2]: Wrapper functions revert on wrong caller
    function test_U_MV_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.claim(address(0), address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(address(0), 0);
    }

    /// @notice U:[MV-3]: `claim` works as expected
    function test_U_MV_03_claim_works_as_expected() public {
        _readsActiveAccount();
        _executesCall({
            tokensToApprove: new address[](0),
            callData: abi.encodeCall(IMellowSimpleLRTVault.claim, (creditAccount, creditAccount, 1000))
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.claim(address(0), address(0), 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MV-4]: `withdrawPhantomToken` works as expected
    function test_U_MV_04_withdrawPhantomToken_works_as_expected() public {
        // Test with incorrect token
        vm.expectRevert(IMellow4626VaultAdapter.IncorrectStakedPhantomTokenException.selector);
        vm.prank(creditFacade);
        adapter.withdrawPhantomToken(address(0), 1000);

        // Test with correct token
        _readsActiveAccount();
        _executesCall({
            tokensToApprove: new address[](0),
            callData: abi.encodeCall(IMellowSimpleLRTVault.claim, (creditAccount, creditAccount, 1000))
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawPhantomToken(stakedPhantomToken, 1000);
        assertFalse(useSafePrices);
    }
}
