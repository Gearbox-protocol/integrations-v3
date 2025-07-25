// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Mellow4626VaultAdapter} from "../../../../adapters/mellow/Mellow4626VaultAdapter.sol";
import {IMellowSimpleLRTVault} from "../../../../integrations/mellow/IMellowSimpleLRTVault.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IPhantomTokenAdapter} from "../../../../interfaces/IPhantomTokenAdapter.sol";
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

        bytes[] memory retdatas = new bytes[](2);

        retdatas[0] = abi.encode(2000);
        retdatas[1] = abi.encode(3000);

        vm.mockCalls(asset, abi.encodeCall(IERC20.balanceOf, (creditAccount)), retdatas);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.claim(address(0), address(0), 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MV-4]: `withdrawPhantomToken` works as expected
    function test_U_MV_04_withdrawPhantomToken_works_as_expected() public {
        // Test with incorrect token
        vm.expectRevert(IPhantomTokenAdapter.IncorrectStakedPhantomTokenException.selector);
        vm.prank(creditFacade);
        adapter.withdrawPhantomToken(address(0), 1000);

        // Test with correct token
        _readsActiveAccount();
        _executesCall({
            tokensToApprove: new address[](0),
            callData: abi.encodeCall(IMellowSimpleLRTVault.claim, (creditAccount, creditAccount, 1000))
        });

        bytes[] memory retdatas = new bytes[](2);

        retdatas[0] = abi.encode(2000);
        retdatas[1] = abi.encode(3000);

        vm.mockCalls(asset, abi.encodeCall(IERC20.balanceOf, (creditAccount)), retdatas);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawPhantomToken(stakedPhantomToken, 1000);
        assertFalse(useSafePrices);
    }

    function test_U_MV_05_inherited_withdraw_works_as_expected() public {
        _revertsOnNonFacadeCaller();
        adapter.withdraw(1000, address(0), address(0));

        _readsActiveAccount();
        _executesSwap({
            tokenIn: vault,
            callData: abi.encodeCall(IERC4626.withdraw, (1000, creditAccount, creditAccount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdraw(1000, address(0), address(0));
        assertTrue(useSafePrices);
    }

    function test_U_MV_06_inherited_redeem_works_as_expected() public {
        _revertsOnNonFacadeCaller();
        adapter.redeem(1000, address(0), address(0));

        _readsActiveAccount();
        _executesSwap({
            tokenIn: vault,
            callData: abi.encodeCall(IERC4626.redeem, (1000, creditAccount, creditAccount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeem(1000, address(0), address(0));
        assertTrue(useSafePrices);
    }

    function test_U_MV_07_inherited_redeemDiff_works_as_expected() public diffTestCases {
        _revertsOnNonFacadeCaller();
        adapter.redeemDiff(1000);

        deal({token: vault, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: vault,
            callData: abi.encodeCall(IERC4626.redeem, (diffInputAmount, creditAccount, creditAccount)),
            requiresApproval: false
        });
        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemDiff(diffLeftoverAmount);
        assertTrue(useSafePrices);
    }
}
