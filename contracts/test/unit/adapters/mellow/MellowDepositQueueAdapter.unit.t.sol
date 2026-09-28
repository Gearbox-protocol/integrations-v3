// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MellowDepositQueueAdapter} from "../../../../adapters/mellow/MellowDepositQueueAdapter.sol";
import {MellowFlexibleDepositGateway} from "../../../../helpers/mellow/MellowFlexibleDepositGateway.sol";
import {MellowFlexibleDepositPhantomToken} from "../../../../helpers/mellow/MellowFlexibleDepositPhantomToken.sol";
import {IMellowFlexibleDepositGateway} from "../../../../interfaces/mellow/IMellowFlexibleDepositGateway.sol";
import {IMellowDepositQueueAdapter} from "../../../../interfaces/mellow/IMellowDepositQueueAdapter.sol";
import {IMellowDepositQueue} from "../../../../integrations/mellow/IMellowDepositQueue.sol";
import {IMellowFlexibleVault} from "../../../../integrations/mellow/IMellowFlexibleVault.sol";
import {IPhantomTokenAdapter} from "../../../../interfaces/IPhantomTokenAdapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Mellow deposit queue adapter unit test
/// @notice U:[MDQ]: Unit tests for Mellow deposit queue adapter
contract MellowDepositQueueAdapterUnitTest is AdapterUnitTestHelper {
    MellowDepositQueueAdapter adapter;

    address gateway;
    address asset;
    address phantomToken;
    address referral;
    address depositQueue;
    address mellowRateOracle;
    address vault;
    address vaultToken;

    function setUp() public {
        _setUp();

        asset = tokens[0];
        vaultToken = tokens[1];
        referral = makeAddr("REFERRAL");
        depositQueue = makeAddr("DEPOSIT_QUEUE");
        mellowRateOracle = makeAddr("MELLOW_RATE_ORACLE");
        vault = makeAddr("VAULT");

        vm.mockCall(depositQueue, abi.encodeWithSignature("asset()"), abi.encode(asset));
        vm.mockCall(depositQueue, abi.encodeWithSignature("vault()"), abi.encode(vault));
        vm.mockCall(vault, abi.encodeWithSignature("shareManager()"), abi.encode(vaultToken));

        gateway = address(new MellowFlexibleDepositGateway(depositQueue));

        vm.mockCall(gateway, abi.encodeWithSignature("asset()"), abi.encode(asset));
        vm.mockCall(gateway, abi.encodeWithSignature("vaultToken()"), abi.encode(vaultToken));

        vm.mockCall(asset, abi.encodeWithSignature("name()"), abi.encode("Test Asset"));
        vm.mockCall(asset, abi.encodeWithSignature("symbol()"), abi.encode("TST"));
        vm.mockCall(vaultToken, abi.encodeWithSignature("name()"), abi.encode("Test Vault"));
        vm.mockCall(vaultToken, abi.encodeWithSignature("symbol()"), abi.encode("vTST"));
        vm.mockCall(vaultToken, abi.encodeWithSignature("decimals()"), abi.encode(uint8(18)));

        phantomToken = address(new MellowFlexibleDepositPhantomToken(gateway, mellowRateOracle));

        creditManager.setMask(phantomToken, 1 << 10);

        adapter = new MellowDepositQueueAdapter(address(creditManager), gateway, referral, phantomToken);
    }

    /// @notice U:[MDQ-1]: Constructor works as expected
    function test_U_MDQ_01_constructor_works_as_expected() public {
        address wrongGateway = makeAddr("WRONG_GATEWAY");
        vm.mockCall(wrongGateway, abi.encodeWithSignature("asset()"), abi.encode(asset));
        vm.mockCall(wrongGateway, abi.encodeWithSignature("vaultToken()"), abi.encode(vaultToken));
        address wrongPhantomToken = address(new MellowFlexibleDepositPhantomToken(wrongGateway, mellowRateOracle));

        creditManager.setMask(wrongPhantomToken, 1 << 11);

        vm.expectRevert(IMellowDepositQueueAdapter.InvalidDepositQueueGatewayException.selector);
        new MellowDepositQueueAdapter(address(creditManager), gateway, referral, wrongPhantomToken);

        phantomToken = address(new MellowFlexibleDepositPhantomToken(gateway, mellowRateOracle));
        creditManager.setMask(phantomToken, 1 << 12);

        _readsTokenMask(asset);
        _readsTokenMask(phantomToken);

        adapter = new MellowDepositQueueAdapter(address(creditManager), gateway, referral, phantomToken);

        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.targetContract(), gateway, "Incorrect targetContract");
        assertEq(adapter.asset(), asset, "Incorrect asset");
        assertEq(adapter.phantomToken(), phantomToken, "Incorrect phantomToken");
        assertEq(adapter.referral(), referral, "Incorrect referral");
    }

    /// @notice U:[MDQ-2]: Wrapper functions revert on wrong caller
    function test_U_MDQ_02_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.deposit(1000, address(0), new bytes32[](0));

        _revertsOnNonFacadeCaller();
        adapter.depositDiff(1000);

        _revertsOnNonFacadeCaller();
        adapter.cancelDepositRequest();

        _revertsOnNonFacadeCaller();
        adapter.claim(1000);

        _revertsOnNonFacadeCaller();
        adapter.withdrawPhantomToken(address(0), 0);

        _revertsOnNonFacadeCaller();
        adapter.depositPhantomToken(address(0), 0);
    }

    /// @notice U:[MDQ-3]: `deposit` works as expected
    function test_U_MDQ_03_deposit_works_as_expected() public {
        bytes32[] memory merkleProof = new bytes32[](0);

        _executesSwap({
            tokenIn: asset,
            callData: abi.encodeCall(IMellowFlexibleDepositGateway.deposit, (1000, referral, merkleProof)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.deposit(1000, makeAddr("IGNORED_REFERRAL"), merkleProof);
        assertTrue(useSafePrices);
    }

    /// @notice U:[MDQ-4]: `depositDiff` works as expected
    function test_U_MDQ_04_depositDiff_works_as_expected() public diffTestCases {
        deal({token: asset, to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();

        bytes32[] memory merkleProof = new bytes32[](0);
        _executesSwap({
            tokenIn: asset,
            callData: abi.encodeCall(IMellowFlexibleDepositGateway.deposit, (diffInputAmount, referral, merkleProof)),
            requiresApproval: true
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositDiff(diffLeftoverAmount);
        assertTrue(useSafePrices);
    }

    /// @notice U:[MDQ-5]: `depositDiff` returns false when amount <= leftoverAmount
    function test_U_MDQ_05_depositDiff_returns_false_when_nothing_to_deposit() public {
        deal({token: asset, to: creditAccount, give: 100});

        _readsActiveAccount();

        vm.prank(creditFacade);
        bool useSafePrices = adapter.depositDiff(100);
        assertFalse(useSafePrices);

        vm.prank(creditFacade);
        useSafePrices = adapter.depositDiff(101);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MDQ-6]: `cancelDepositRequest` works as expected
    function test_U_MDQ_06_cancelDepositRequest_works_as_expected() public {
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMellowFlexibleDepositGateway.cancelDepositRequest, ()),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.cancelDepositRequest();
        assertFalse(useSafePrices);
    }

    /// @notice U:[MDQ-7]: `claim` works as expected
    function test_U_MDQ_07_claim_works_as_expected() public {
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMellowFlexibleDepositGateway.claim, (1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.claim(1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MDQ-8]: `withdrawPhantomToken` works as expected
    function test_U_MDQ_08_withdrawPhantomToken_works_as_expected() public {
        // Test with incorrect token
        vm.expectRevert(IPhantomTokenAdapter.IncorrectStakedPhantomTokenException.selector);
        vm.prank(creditFacade);
        adapter.withdrawPhantomToken(address(0), 1000);

        // Test with correct token
        _executesSwap({
            tokenIn: address(0),
            callData: abi.encodeCall(IMellowFlexibleDepositGateway.claim, (1000)),
            requiresApproval: false
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.withdrawPhantomToken(phantomToken, 1000);
        assertFalse(useSafePrices);
    }

    /// @notice U:[MDQ-9]: `depositPhantomToken` reverts as expected
    function test_U_MDQ_09_depositPhantomToken_reverts() public {
        vm.prank(creditFacade);
        vm.expectRevert(NotImplementedException.selector);
        adapter.depositPhantomToken(phantomToken, 1000);
    }

    /// @notice U:[MDQ-10]: `serialize` works as expected
    function test_U_MDQ_10_serialize_works_as_expected() public view {
        bytes memory serializedData = adapter.serialize();
        (address cm, address tc, address a, address pt, address r) =
            abi.decode(serializedData, (address, address, address, address, address));

        assertEq(cm, address(creditManager), "Incorrect creditManager in serialized data");
        assertEq(tc, gateway, "Incorrect targetContract in serialized data");
        assertEq(a, asset, "Incorrect asset in serialized data");
        assertEq(pt, phantomToken, "Incorrect phantomToken in serialized data");
        assertEq(r, referral, "Incorrect referral in serialized data");
    }
}
