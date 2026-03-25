// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {
    SecuritizeRedemptionGatewayAdapter
} from "../../../../adapters/securitize/SecuritizeRedemptionGatewayAdapter.sol";
import {SecuritizeRedemptionPhantomToken} from "../../../../helpers/securitize/SecuritizeRedemptionPhantomToken.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {ISecuritizeRedemptionGateway} from "../../../../interfaces/securitize/ISecuritizeRedemptionGateway.sol";
import {ISecuritizeWhitelister, Signature} from "../../../../integrations/securitize/ISecuritizeWhitelister.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

contract SecuritizeRedemptionGatewayMock is ISecuritizeRedemptionGateway {
    address internal _dsToken;
    address internal _stableCoinToken;

    constructor(address dsToken, address stableCoinToken) {
        _dsToken = dsToken;
        _stableCoinToken = stableCoinToken;
    }

    function contractType() external pure override returns (bytes32) {
        return "MOCK::GATEWAY";
    }

    function version() external pure override returns (uint256) {
        return 0;
    }

    function dsToken() external view override returns (address) {
        return _dsToken;
    }

    function stableCoinToken() external view override returns (address) {
        return _stableCoinToken;
    }

    function redemptionAccount() external view override returns (address) {
        return address(0);
    }

    function securitizeWhitelister() external view override returns (address) {
        return address(0);
    }

    function masterRedeemer() external view override returns (address) {
        return address(0);
    }

    function transferMaster() external view override returns (address) {
        return address(0);
    }

    function redeem(uint256, Signature calldata) external override {}

    function claim(address[] calldata) external override {}

    function transferRedeemer(address, address) external override {}

    function getRedemptionAmount(address) external view override returns (uint256) {
        return 0;
    }

    function getRedeemers(address) external view override returns (address[] memory) {
        address[] memory empty;
        return empty;
    }

    function getUnclaimedRedeemers(address) external view override returns (address[] memory) {
        address[] memory empty;
        return empty;
    }
}

/// @title Securitize Redemption Gateway adapter unit test
/// @notice U:[SRG-A]: Unit tests for SecuritizeRedemptionGatewayAdapter
contract SecuritizeRedemptionGatewayAdapterUnitTest is AdapterUnitTestHelper {
    SecuritizeRedemptionGatewayAdapter adapter;
    SecuritizeRedemptionGatewayMock gateway;
    SecuritizeRedemptionPhantomToken phantomToken;

    address dsToken;
    address stableCoinToken;
    Signature userSignature;

    function setUp() public {
        _setUp();

        dsToken = tokens[0];
        stableCoinToken = tokens[1];
        userSignature = Signature({deadline: 1, signature: hex"deadbeef"});

        gateway = new SecuritizeRedemptionGatewayMock(dsToken, stableCoinToken);
        phantomToken = new SecuritizeRedemptionPhantomToken(address(gateway));

        // Adapter constructor requires the phantom token to be a known collateral.
        creditManager.setMask(address(phantomToken), 1 << 5);

        adapter =
            new SecuritizeRedemptionGatewayAdapter(address(creditManager), address(gateway), address(phantomToken));
    }

    /// @notice U:[SRG-A-1]: Constructor works as expected
    function test_U_SRG_A_01_constructor_works_as_expected() public {
        _readsTokenMask(dsToken);
        _readsTokenMask(stableCoinToken);
        _readsTokenMask(address(phantomToken));

        adapter =
            new SecuritizeRedemptionGatewayAdapter(address(creditManager), address(gateway), address(phantomToken));

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), address(gateway), "Incorrect targetContract");
        assertEq(adapter.dsToken(), dsToken, "Incorrect dsToken");
        assertEq(adapter.stableCoinToken(), stableCoinToken, "Incorrect stableCoinToken");
        assertEq(adapter.redemptionPhantomToken(), address(phantomToken), "Incorrect redemptionPhantomToken");
    }

    /// @notice U:[SRG-A-2]: Wrapper functions revert on wrong caller
    function test_U_SRG_A_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.redeem(1000, userSignature);

        _revertsOnNonFacadeCaller();
        adapter.redeemDiff(100, userSignature);

        _revertsOnNonFacadeCaller();
        adapter.claim(new address[](0));

        _revertsOnNonFacadeCaller();
        adapter.transferRedeemer(makeAddr("REDEEMER"), makeAddr("NEW_ACCOUNT"));

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.depositPhantomToken(address(0), 0);
    }

    /// @notice U:[SRG-A-3]: `redeem` works as expected (executes swap + returns false)
    function test_U_SRG_A_03_redeem_works_as_expected() public {
        uint256 dsTokenAmount = 1_234;

        _executesSwap({
            tokenIn: dsToken,
            callData: abi.encodeCall(ISecuritizeRedemptionGateway.redeem, (dsTokenAmount, userSignature)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeem(dsTokenAmount, userSignature);
        assertFalse(useSafePrices);
    }

    /// @notice U:[SRG-A-4]: `redeemDiff` returns false when balance <= leftover
    function test_U_SRG_A_04_redeemDiff_returns_false_when_nothing_to_redeem() public {
        deal(dsToken, creditAccount, 1_000);

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemDiff(1_000, userSignature);
        assertFalse(useSafePrices);
    }

    /// @notice U:[SRG-A-5]: `redeemDiff` works as expected (executes swap + returns false)
    function test_U_SRG_A_05_redeemDiff_works_as_expected() public {
        deal(dsToken, creditAccount, 1_000);
        uint256 leftoverAmount = 100;
        uint256 dsTokenAmount = 900;

        _executesSwap({
            tokenIn: dsToken,
            callData: abi.encodeCall(ISecuritizeRedemptionGateway.redeem, (dsTokenAmount, userSignature)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemDiff(leftoverAmount, userSignature);
        assertFalse(useSafePrices);
    }

    /// @notice U:[SRG-A-6]: `claim` works as expected
    function test_U_SRG_A_06_claim_works_as_expected() public {
        address redeemer1 = makeAddr("REDEEMER_1");
        address redeemer2 = makeAddr("REDEEMER_2");
        address[] memory redeemers = _toArray(redeemer1, redeemer2);

        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(ISecuritizeRedemptionGateway.claim, (redeemers)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.claim(redeemers);
        assertFalse(useSafePrices);
    }

    /// @notice U:[SRG-A-7]: `transferRedeemer` works as expected
    function test_U_SRG_A_07_transferRedeemer_works_as_expected() public {
        address redeemer = makeAddr("REDEEMER");
        address newAccount = makeAddr("NEW_ACCOUNT");

        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(ISecuritizeRedemptionGateway.transferRedeemer, (redeemer, newAccount)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.transferRedeemer(redeemer, newAccount);
        assertTrue(useSafePrices);
    }

    /// @notice U:[SRG-A-8]: withdrawPhantomToken reverts as expected
    function test_U_SRG_A_08_withdrawPhantomToken_reverts() public {
        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.withdrawPhantomToken(address(0), 0);
    }

    /// @notice U:[SRG-A-9]: depositPhantomToken reverts as expected
    function test_U_SRG_A_09_depositPhantomToken_reverts() public {
        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.depositPhantomToken(address(0), 0);
    }

    /// @notice U:[SRG-A-10]: `serialize` works as expected
    function test_U_SRG_A_10_serialize_works_as_expected() public {
        bytes memory serializedData = adapter.serialize();
        (address cm, address tc, address ds, address sc, address phantom) =
            abi.decode(serializedData, (address, address, address, address, address));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, address(gateway), "Incorrect targetContract in serialized data");
        assertEq(ds, dsToken, "Incorrect dsToken in serialized data");
        assertEq(sc, stableCoinToken, "Incorrect stableCoinToken in serialized data");
        assertEq(phantom, address(phantomToken), "Incorrect redemptionPhantomToken in serialized data");
    }

    function _toArray(address a, address b) internal pure returns (address[] memory arr) {
        arr = new address[](2);
        arr[0] = a;
        arr[1] = b;
    }
}

