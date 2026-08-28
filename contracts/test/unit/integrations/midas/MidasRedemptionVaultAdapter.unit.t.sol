// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {RAY, WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {TokenNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasRedemptionVaultAdapter} from "../../../../integrations/midas/MidasRedemptionVaultAdapter.sol";
import {IMidasRedemptionVault} from "../../../../integrations/midas/interfaces/external/IMidasRedemptionVault.sol";
import {IMidasRedemptionVaultAdapter} from "../../../../integrations/midas/interfaces/IMidasRedemptionVaultAdapter.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @dev Minimal redemption vault mock - the adapter reads mToken from it.
contract MidasRedemptionVaultAdapterMock {
    address public immutable mToken;

    constructor(address _mToken) {
        mToken = _mToken;
    }
}

/// @title Midas Redemption Vault adapter unit test
/// @notice U:[MID-RVA]: Unit tests for MidasRedemptionVaultAdapter
contract MidasRedemptionVaultAdapterUnitTest is AdapterUnitTestHelper {
    MidasRedemptionVaultAdapter adapter;
    MidasRedemptionVaultAdapterMock redemptionVault;

    address mToken;
    address quoteToken;

    function setUp() public {
        _setUp();

        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        creditManager.setMask(mToken, 1 << 9);

        quoteToken = tokens[0];

        redemptionVault = new MidasRedemptionVaultAdapterMock(mToken);
        adapter = new MidasRedemptionVaultAdapter(address(creditManager), address(redemptionVault));

        _allowToken(quoteToken);
    }

    function _allowToken(address token) internal {
        address[] memory tokens_ = new address[](1);
        bool[] memory statuses = new bool[](1);
        tokens_[0] = token;
        statuses[0] = true;
        vm.prank(configurator);
        adapter.setOutputTokenStatusBatch(tokens_, statuses);
    }

    /// @notice U:[MID-RVA-1]: Constructor works as expected
    function test_U_MID_RVA_01_constructor_works_as_expected() public {
        _readsTokenMask(mToken);

        adapter = new MidasRedemptionVaultAdapter(address(creditManager), address(redemptionVault));

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(redemptionVault), "Incorrect targetContract");
        assertEq(adapter.mToken(), mToken, "Incorrect mToken");
        assertEq(adapter.contractType(), "ADAPTER::MIDAS_REDEMPTION_VAULT", "Incorrect contractType");
        assertEq(adapter.version(), 3_11, "Incorrect version");
        assertEq(adapter.supportedOutputTokens().length, 0, "Should start with no allowed tokens");
    }

    /// @notice U:[MID-RVA-2]: Wrapper functions revert on wrong caller
    function test_U_MID_RVA_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.redeemInstant(quoteToken, 1000, 0);

        _revertsOnNonFacadeCaller();
        adapter.redeemInstantDiff(quoteToken, 1, 0);
    }

    /// @notice U:[MID-RVA-3]: `redeemInstant` works as expected (encodes minReceive as e18)
    function test_U_MID_RVA_03_redeemInstant_works() public {
        uint256 amountMTokenIn = 1000;
        uint256 minReceiveAmount = 500;

        _executesSwap({
            tokenIn: mToken,
            callData: abi.encodeCall(
                IMidasRedemptionVault.redeemInstant, (quoteToken, amountMTokenIn, minReceiveAmount)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemInstant(quoteToken, amountMTokenIn, minReceiveAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-RVA-3A]: `redeemInstant` converts non-18-decimal minReceive to e18
    function test_U_MID_RVA_03A_redeemInstant_converts_minReceive_to_e18() public {
        address usdc = address(new ERC20Mock("USDC", "USDC", 6));
        creditManager.setMask(usdc, 1 << 10);
        _allowToken(usdc);

        uint256 amountMTokenIn = 1000e18;
        uint256 minReceiveAmount = 950e6;
        uint256 minReceiveAmountE18 = minReceiveAmount * WAD / 1e6;

        _executesSwap({
            tokenIn: mToken,
            callData: abi.encodeCall(IMidasRedemptionVault.redeemInstant, (usdc, amountMTokenIn, minReceiveAmountE18)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemInstant(usdc, amountMTokenIn, minReceiveAmount);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-RVA-3B]: `redeemInstant` reverts for disallowed token
    function test_U_MID_RVA_03B_redeemInstant_reverts_for_disallowed_token() public {
        vm.expectRevert(TokenNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.redeemInstant(tokens[1], 1000, 0);
    }

    /// @notice U:[MID-RVA-4]: `redeemInstantDiff` works as expected
    function test_U_MID_RVA_04_redeemInstantDiff_works() public {
        deal(mToken, creditAccount, 1000);
        uint256 leftover = 100;
        uint256 amount = 900;
        uint256 minReceive = (amount * RAY) / RAY;

        _executesSwap({
            tokenIn: mToken,
            callData: abi.encodeCall(IMidasRedemptionVault.redeemInstant, (quoteToken, amount, minReceive)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemInstantDiff(quoteToken, leftover, RAY);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-RVA-5]: `redeemInstantDiff` is a no-op when balance <= leftover
    function test_U_MID_RVA_05_redeemInstantDiff_noop_when_nothing_to_redeem() public {
        deal(mToken, creditAccount, 100);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemInstantDiff(quoteToken, 100, RAY);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-RVA-6]: `setOutputTokenStatusBatch` works as expected
    function test_U_MID_RVA_06_setOutputTokenStatusBatch_works_as_expected() public {
        address[] memory tokens_ = new address[](2);
        bool[] memory statuses = new bool[](2);
        tokens_[0] = tokens[0];
        tokens_[1] = tokens[1];
        statuses[0] = false;
        statuses[1] = true;

        _revertsOnNonConfiguratorCaller();
        adapter.setOutputTokenStatusBatch(tokens_, statuses);

        _readsTokenMask(tokens[1]);

        vm.expectEmit(true, false, false, true);
        emit IMidasRedemptionVaultAdapter.SetOutputTokenStatus(tokens[0], false);
        vm.expectEmit(true, false, false, true);
        emit IMidasRedemptionVaultAdapter.SetOutputTokenStatus(tokens[1], true);

        vm.prank(configurator);
        adapter.setOutputTokenStatusBatch(tokens_, statuses);

        assertFalse(adapter.isOutputTokenAllowed(tokens[0]), "First token incorrectly allowed");
        assertTrue(adapter.isOutputTokenAllowed(tokens[1]), "Second token incorrectly not allowed");

        address[] memory allowed = adapter.supportedOutputTokens();
        assertEq(allowed.length, 1, "Incorrect allowed tokens length");
        assertEq(allowed[0], tokens[1], "Incorrect allowed token");
    }

    /// @notice U:[MID-RVA-6A]: `setOutputTokenStatusBatch` reverts on length mismatch
    function test_U_MID_RVA_06A_setOutputTokenStatusBatch_reverts_on_length_mismatch() public {
        address[] memory tokens_ = new address[](2);
        bool[] memory statuses = new bool[](1);

        vm.expectRevert(IMidasRedemptionVaultAdapter.IncorrectArrayLengthException.selector);
        vm.prank(configurator);
        adapter.setOutputTokenStatusBatch(tokens_, statuses);
    }

    /// @notice U:[MID-RVA-7]: `serialize` works as expected
    function test_U_MID_RVA_07_serialize_works() public view {
        bytes memory serializedData = adapter.serialize();
        (address cm, address tc, address mtoken, address[] memory allowed) =
            abi.decode(serializedData, (address, address, address, address[]));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, address(redemptionVault), "Incorrect targetContract in serialized data");
        assertEq(mtoken, mToken, "Incorrect mToken in serialized data");
        assertEq(allowed.length, 1, "Incorrect allowed tokens length");
        assertEq(allowed[0], quoteToken, "Incorrect allowed token");
    }
}
