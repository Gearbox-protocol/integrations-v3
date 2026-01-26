// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MellowRedeemQueueAdapter} from "../../../../adapters/mellow/MellowRedeemQueueAdapter.sol";
import {MellowFlexibleRedeemGateway} from "../../../../helpers/mellow/MellowFlexibleRedeemGateway.sol";
import {MellowFlexibleRedeemPhantomToken} from "../../../../helpers/mellow/MellowFlexibleRedeemPhantomToken.sol";
import {IMellowFlexibleRedeemGateway} from "../../../../interfaces/mellow/IMellowFlexibleRedeemGateway.sol";
import {IMellowRedeemQueueAdapter} from "../../../../interfaces/mellow/IMellowRedeemQueueAdapter.sol";
import {IMellowRedeemQueue} from "../../../../integrations/mellow/IMellowRedeemQueue.sol";
import {IMellowFlexibleVault} from "../../../../integrations/mellow/IMellowFlexibleVault.sol";
import {IPhantomTokenAdapter} from "../../../../interfaces/IPhantomTokenAdapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Mellow redeem queue adapter unit test
/// @notice U:[MRQ]: Unit tests for Mellow redeem queue adapter
contract MellowRedeemQueueAdapterUnitTest is AdapterUnitTestHelper {
    MellowRedeemQueueAdapter adapter;

    address gateway;
    address vaultToken;
    address phantomToken;
    address redeemQueue;
    address asset;
    address mellowRateOracle;
    address vault;

    function setUp() public {
        _setUp();

        vaultToken = tokens[0];
        asset = tokens[1];
        redeemQueue = makeAddr("REDEEM_QUEUE");
        mellowRateOracle = makeAddr("MELLOW_RATE_ORACLE");
        vault = makeAddr("VAULT");

        vm.mockCall(redeemQueue, abi.encodeWithSignature("asset()"), abi.encode(asset));
        vm.mockCall(redeemQueue, abi.encodeWithSignature("vault()"), abi.encode(vault));
        vm.mockCall(vault, abi.encodeWithSignature("shareManager()"), abi.encode(vaultToken));

        gateway = address(new MellowFlexibleRedeemGateway(redeemQueue));

        vm.mockCall(gateway, abi.encodeWithSignature("asset()"), abi.encode(asset));
        vm.mockCall(gateway, abi.encodeWithSignature("vaultToken()"), abi.encode(vaultToken));

        vm.mockCall(asset, abi.encodeWithSignature("name()"), abi.encode("Test Asset"));
        vm.mockCall(asset, abi.encodeWithSignature("symbol()"), abi.encode("TST"));
        vm.mockCall(vaultToken, abi.encodeWithSignature("name()"), abi.encode("Test Vault"));
        vm.mockCall(vaultToken, abi.encodeWithSignature("symbol()"), abi.encode("vTST"));
        vm.mockCall(vaultToken, abi.encodeWithSignature("decimals()"), abi.encode(uint8(18)));

        phantomToken = address(new MellowFlexibleRedeemPhantomToken(gateway, mellowRateOracle));

        creditManager.setMask(phantomToken, 1 << 10);

        adapter = new MellowRedeemQueueAdapter(address(creditManager), gateway, phantomToken);
    }

    /// @notice U:[MRQ-1]: Constructor works as expected
    function test_U_MRQ_01_constructor_works_as_expected() public {
        // Should revert if phantom token points to wrong gateway
        address wrongGateway = makeAddr("WRONG_GATEWAY");
        vm.mockCall(wrongGateway, abi.encodeWithSignature("asset()"), abi.encode(asset));
        vm.mockCall(wrongGateway, abi.encodeWithSignature("vaultToken()"), abi.encode(vaultToken));
        address wrongPhantomToken = address(new MellowFlexibleRedeemPhantomToken(wrongGateway, mellowRateOracle));

        // Register wrong phantom token in credit manager to avoid token not recognized error
        creditManager.setMask(wrongPhantomToken, 1 << 11);

        vm.expectRevert(IMellowRedeemQueueAdapter.InvalidRedeemQueueGatewayException.selector);
        new MellowRedeemQueueAdapter(address(creditManager), gateway, wrongPhantomToken);

        // Deploy new phantom token and register it
        phantomToken = address(new MellowFlexibleRedeemPhantomToken(gateway, mellowRateOracle));
        creditManager.setMask(phantomToken, 1 << 12);

        _readsTokenMask(vaultToken);
        _readsTokenMask(phantomToken);

        adapter = new MellowRedeemQueueAdapter(address(creditManager), gateway, phantomToken);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), gateway, "Incorrect targetContract");
        assertEq(adapter.vaultToken(), vaultToken, "Incorrect vaultToken");
        assertEq(adapter.phantomToken(), phantomToken, "Incorrect phantomToken");
    }

    /// @notice U:[MRQ-2]: Wrapper functions revert on wrong caller
    function test_U_MRQ_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.redeem(1000);

        _revertsOnNonFacadeCaller();
        adapter.redeemDiff(1000);

        _revertsOnNonFacadeCaller();
        adapter.claim(1000);

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.depositPhantomToken(address(0), 0);
    }

    /// @notice U:[MRQ-3]: `redeem` works as expected
    function test_U_MRQ_03_redeem_works_as_expected() public {
        _executesSwap({
            tokenIn: vaultToken,
            callData: abi.encodeCall(IMellowFlexibleRedeemGateway.redeem, (1000)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeem(1000);
        assertTrue(useSafePrices);
    }

    /// @notice U:[MRQ-4]: `redeemDiff` works as expected
    function test_U_MRQ_04_redeemDiff_works_as_expected() public diffTestCases {
        deal({token: vaultToken, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();

        _executesSwap({
            tokenIn: vaultToken,
            callData: abi.encodeCall(IMellowFlexibleRedeemGateway.redeem, (diffInputAmount)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemDiff(diffLeftoverAmount);
        assertTrue(useSafePrices);
    }

    /// @notice U:[MRQ-5]: `redeemDiff` returns false when amount <= leftoverAmount
    function test_U_MRQ_05_redeemDiff_returns_false_when_nothing_to_redeem() public {
        deal({token: vaultToken, to: creditAccount, give: 100});

        _readsActiveAccount();

        vm.prank(creditFacade);
        bool useSafePrices = adapter.redeemDiff(100);
        assertFalse(useSafePrices);

        vm.prank(creditFacade);
        useSafePrices = adapter.redeemDiff(101);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MRQ-6]: `claim` works as expected
    function test_U_MRQ_06_claim_works_as_expected() public {
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMellowFlexibleRedeemGateway.claim, (1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.claim(1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MRQ-7]: `withdrawPhantomToken` works as expected
    function test_U_MRQ_07_withdrawPhantomToken_works_as_expected() public {
        // Test with incorrect token
        vm.expectRevert(IPhantomTokenAdapter.IncorrectStakedPhantomTokenException.selector);
        vm.prank(creditFacade);
        adapter.withdrawPhantomToken(address(0), 1000);

        // Test with correct token
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMellowFlexibleRedeemGateway.claim, (1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawPhantomToken(phantomToken, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MRQ-8]: `depositPhantomToken` reverts as expected
    function test_U_MRQ_08_depositPhantomToken_reverts() public {
        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.depositPhantomToken(phantomToken, 1000);
    }

    /// @notice U:[MRQ-9]: `serialize` works as expected
    function test_U_MRQ_09_serialize_works_as_expected() public view {
        bytes memory serializedData = adapter.serialize();
        (address cm, address tc, address vt, address pt) =
            abi.decode(serializedData, (address, address, address, address));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, gateway, "Incorrect targetContract in serialized data");
        assertEq(vt, vaultToken, "Incorrect vaultToken in serialized data");
        assertEq(pt, phantomToken, "Incorrect phantomToken in serialized data");
    }
}
