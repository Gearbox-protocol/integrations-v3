// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {RAY, WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {TokenNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasIssuanceVaultAdapter} from "../../../../integrations/midas/MidasIssuanceVaultAdapter.sol";
import {IMidasIssuanceVault} from "../../../../integrations/midas/interfaces/external/IMidasIssuanceVault.sol";
import {IMidasIssuanceVaultAdapter} from "../../../../integrations/midas/interfaces/IMidasIssuanceVaultAdapter.sol";

import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @dev Minimal issuance vault mock - the adapter reads mToken from it.
contract MidasIssuanceVaultMock {
    address public immutable mToken;

    constructor(address _mToken) {
        mToken = _mToken;
    }
}

/// @title Midas Issuance Vault adapter unit test
/// @notice U:[MID-IVA]: Unit tests for MidasIssuanceVaultAdapter
contract MidasIssuanceVaultAdapterUnitTest is AdapterUnitTestHelper {
    MidasIssuanceVaultAdapter adapter;
    MidasIssuanceVaultMock issuanceVault;

    address mToken;
    address quoteToken;

    bytes32 constant REFERRER_ID = bytes32(uint256(0xC0FFEE));

    function setUp() public {
        _setUp();

        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        creditManager.setMask(mToken, 1 << 9);

        quoteToken = tokens[0];

        issuanceVault = new MidasIssuanceVaultMock(mToken);
        adapter = new MidasIssuanceVaultAdapter(address(creditManager), address(issuanceVault), REFERRER_ID);

        _allowToken(quoteToken);
    }

    function _allowToken(address token) internal {
        address[] memory tokens_ = new address[](1);
        bool[] memory statuses = new bool[](1);
        tokens_[0] = token;
        statuses[0] = true;
        vm.prank(configurator);
        adapter.setInputTokenStatusBatch(tokens_, statuses);
    }

    /// @notice U:[MID-IVA-1]: Constructor works as expected
    function test_U_MID_IVA_01_constructor_works_as_expected() public {
        _readsTokenMask(mToken);

        adapter = new MidasIssuanceVaultAdapter(address(creditManager), address(issuanceVault), REFERRER_ID);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(issuanceVault), "Incorrect targetContract");
        assertEq(adapter.issuanceVault(), address(issuanceVault), "Incorrect issuanceVault");
        assertEq(adapter.mToken(), mToken, "Incorrect mToken");
        assertEq(adapter.referrerId(), REFERRER_ID, "Incorrect referrerId");
        assertEq(adapter.contractType(), "ADAPTER::MIDAS_ISSUANCE_VAULT", "Incorrect contractType");
        assertEq(adapter.version(), 3_11, "Incorrect version");
        assertEq(adapter.supportedInputTokens().length, 0, "Should start with no allowed tokens");
    }

    /// @notice U:[MID-IVA-2]: Wrapper functions revert on wrong caller
    function test_U_MID_IVA_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.depositInstant(quoteToken, 1000, 0, REFERRER_ID);

        _revertsOnNonFacadeCaller();
        adapter.depositInstantDiff(quoteToken, 1, 0);
    }

    /// @notice U:[MID-IVA-3]: `depositInstant` works as expected (encodes e18 amount + referrerId)
    function test_U_MID_IVA_03_depositInstant_works() public {
        uint256 amountToken = 1000;
        uint256 minReceiveAmount = 500;

        _executesSwap({
            tokenIn: quoteToken,
            callData: abi.encodeCall(
                IMidasIssuanceVault.depositInstant, (quoteToken, amountToken, minReceiveAmount, REFERRER_ID)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositInstant(quoteToken, amountToken, minReceiveAmount, REFERRER_ID);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-IVA-3A]: `depositInstant` converts non-18-decimal quote amounts to e18
    function test_U_MID_IVA_03A_depositInstant_converts_to_e18() public {
        address usdc = address(new ERC20Mock("USDC", "USDC", 6));
        creditManager.setMask(usdc, 1 << 10);
        _allowToken(usdc);

        uint256 amountToken = 1_000e6;
        uint256 minReceiveAmount = 950e18;
        uint256 amountTokenE18 = amountToken * WAD / 1e6;

        _executesSwap({
            tokenIn: usdc,
            callData: abi.encodeCall(
                IMidasIssuanceVault.depositInstant, (usdc, amountTokenE18, minReceiveAmount, REFERRER_ID)
            ),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositInstant(usdc, amountToken, minReceiveAmount, REFERRER_ID);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-IVA-3B]: `depositInstant` reverts for disallowed token
    function test_U_MID_IVA_03B_depositInstant_reverts_for_disallowed_token() public {
        vm.expectRevert(TokenNotAllowedException.selector);
        vm.prank(creditFacade);
        adapter.depositInstant(tokens[1], 1000, 0, REFERRER_ID);
    }

    /// @notice U:[MID-IVA-4]: `depositInstantDiff` works as expected
    function test_U_MID_IVA_04_depositInstantDiff_works() public {
        deal(quoteToken, creditAccount, 1000);
        uint256 leftover = 100;
        uint256 amount = 900;
        uint256 minReceive = (amount * RAY) / RAY;

        _executesSwap({
            tokenIn: quoteToken,
            callData: abi.encodeCall(IMidasIssuanceVault.depositInstant, (quoteToken, amount, minReceive, REFERRER_ID)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositInstantDiff(quoteToken, leftover, RAY);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-IVA-5]: `depositInstantDiff` is a no-op when balance <= leftover
    function test_U_MID_IVA_05_depositInstantDiff_noop_when_nothing_to_deposit() public {
        deal(quoteToken, creditAccount, 100);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositInstantDiff(quoteToken, 100, RAY);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MID-IVA-6]: `setInputTokenStatusBatch` works as expected
    function test_U_MID_IVA_06_setInputTokenStatusBatch_works_as_expected() public {
        address[] memory tokens_ = new address[](2);
        bool[] memory statuses = new bool[](2);
        tokens_[0] = tokens[0];
        tokens_[1] = tokens[1];
        statuses[0] = false;
        statuses[1] = true;

        _revertsOnNonConfiguratorCaller();
        adapter.setInputTokenStatusBatch(tokens_, statuses);

        _readsTokenMask(tokens[1]);

        vm.expectEmit(true, false, false, true);
        emit IMidasIssuanceVaultAdapter.SetInputTokenStatus(tokens[0], false);
        vm.expectEmit(true, false, false, true);
        emit IMidasIssuanceVaultAdapter.SetInputTokenStatus(tokens[1], true);

        vm.prank(configurator);
        adapter.setInputTokenStatusBatch(tokens_, statuses);

        assertFalse(adapter.isInputTokenAllowed(tokens[0]), "First token incorrectly allowed");
        assertTrue(adapter.isInputTokenAllowed(tokens[1]), "Second token incorrectly not allowed");

        address[] memory allowed = adapter.supportedInputTokens();
        assertEq(allowed.length, 1, "Incorrect allowed tokens length");
        assertEq(allowed[0], tokens[1], "Incorrect allowed token");
    }

    /// @notice U:[MID-IVA-6A]: `setInputTokenStatusBatch` reverts on length mismatch
    function test_U_MID_IVA_06A_setInputTokenStatusBatch_reverts_on_length_mismatch() public {
        address[] memory tokens_ = new address[](2);
        bool[] memory statuses = new bool[](1);

        vm.expectRevert(IMidasIssuanceVaultAdapter.IncorrectArrayLengthException.selector);
        vm.prank(configurator);
        adapter.setInputTokenStatusBatch(tokens_, statuses);
    }

    /// @notice U:[MID-IVA-7]: `serialize` works as expected
    function test_U_MID_IVA_07_serialize_works() public view {
        bytes memory serializedData = adapter.serialize();
        (address cm, address tc, address vault, address mtoken, bytes32 refId, address[] memory allowed) =
            abi.decode(serializedData, (address, address, address, address, bytes32, address[]));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, address(issuanceVault), "Incorrect targetContract in serialized data");
        assertEq(vault, address(issuanceVault), "Incorrect issuanceVault in serialized data");
        assertEq(mtoken, mToken, "Incorrect mToken in serialized data");
        assertEq(refId, REFERRER_ID, "Incorrect referrerId in serialized data");
        assertEq(allowed.length, 1, "Incorrect allowed tokens length");
        assertEq(allowed[0], quoteToken, "Incorrect allowed token");
    }
}
