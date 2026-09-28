// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {ILossPolicy} from "@gearbox-protocol/core-v3/contracts/interfaces/base/ILossPolicy.sol";
import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {PriceFeedParams} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";
import {UNDERLYING_TOKEN_MASK} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {PoolMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/pool/PoolMock.sol";
import {PoolQuotaKeeperMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/pool/PoolQuotaKeeperMock.sol";
import {
    AddressProviderV3ACLMock
} from "@gearbox-protocol/core-v3/contracts/test/mocks/core/AddressProviderV3ACLMock.sol";
import {PriceOracleMock} from "@gearbox-protocol/core-v3/contracts/test/mocks/oracles/PriceOracleMock.sol";

import {MidasAliasedLossPolicyV3} from "../../../../integrations/midas/MidasAliasedLossPolicyV3.sol";
import {RedemptionStatus} from "../../../../integrations/midas/interfaces/external/IMidasRedemptionVault.sol";

contract MidasPhantomTokenMock {
    bytes32 public constant contractType = "PHANTOM_TOKEN::MIDAS_REDEMPTION";
    address public immutable gateway;
    address public immutable underlying;

    constructor(address gateway_, address underlying_) {
        gateway = gateway_;
        underlying = underlying_;
    }

    function getPhantomTokenInfo() external view returns (address, address) {
        return (gateway, underlying);
    }
}

contract NonMidasPhantomTokenMock {
    bytes32 public constant contractType = "PHANTOM_TOKEN::OTHER";
    address public immutable gateway;
    address public immutable underlying;

    constructor(address gateway_, address underlying_) {
        gateway = gateway_;
        underlying = underlying_;
    }

    function getPhantomTokenInfo() external view returns (address, address) {
        return (gateway, underlying);
    }
}

contract MidasGatewayMockForLossPolicy {
    address public midasRedemptionVault;
    mapping(address => address[]) internal _pendingRedeemers;

    function setMidasRedemptionVault(address vault_) external {
        midasRedemptionVault = vault_;
    }

    function setPendingRedeemers(address account, address[] memory redeemers) external {
        delete _pendingRedeemers[account];
        for (uint256 i; i < redeemers.length; ++i) {
            _pendingRedeemers[account].push(redeemers[i]);
        }
    }

    function pendingRedeemers(address account) external view returns (address[] memory) {
        return _pendingRedeemers[account];
    }
}

contract MidasRedeemerMockForLossPolicy {
    uint256 public requestId;

    constructor(uint256 requestId_) {
        requestId = requestId_;
    }
}

contract MidasRedemptionVaultMockForLossPolicy {
    mapping(uint256 => RedemptionStatus) internal _status;

    function setStatus(uint256 requestId, RedemptionStatus status) external {
        _status[requestId] = status;
    }

    function redeemRequests(uint256 requestId)
        external
        view
        returns (address, address, RedemptionStatus, uint256, uint256, uint256)
    {
        return (address(0), address(0), _status[requestId], 0, 0, 0);
    }
}

/// @title MidasAliasedLossPolicyV3 unit test
/// @notice U:[MID-ALP]: Unit tests for Midas aliased loss policy
contract MidasAliasedLossPolicyV3UnitTest is Test {
    MidasAliasedLossPolicyV3 lossPolicy;

    address configurator;
    address caller;
    address creditAccount;
    address creditManager;

    ERC20Mock underlying;
    AddressProviderV3ACLMock addressProviderMock;
    PoolMock poolMock;
    PriceOracleMock priceOracleMock;

    MidasGatewayMockForLossPolicy gateway;
    MidasRedemptionVaultMockForLossPolicy vault;
    MidasPhantomTokenMock midasPhantom;
    NonMidasPhantomTokenMock otherPhantom;
    MidasRedeemerMockForLossPolicy redeemer;

    uint256 constant MIDAS_TOKEN_MASK = 2;
    uint256 constant OTHER_TOKEN_MASK = 4;

    function setUp() public {
        configurator = makeAddr("CONFIGURATOR");
        caller = makeAddr("CALLER");
        creditAccount = makeAddr("CREDIT_ACCOUNT");
        creditManager = makeAddr("CREDIT_MANAGER");

        underlying = new ERC20Mock("Underlying", "UND", 18);

        vm.prank(configurator);
        addressProviderMock = new AddressProviderV3ACLMock();

        poolMock = new PoolMock(address(addressProviderMock), address(underlying));
        PoolQuotaKeeperMock poolQuotaKeeperMock = new PoolQuotaKeeperMock(address(poolMock), address(underlying));
        poolMock.setPoolQuotaKeeper(address(poolQuotaKeeperMock));

        priceOracleMock = new PriceOracleMock();
        priceOracleMock.setPrice(address(underlying), 1e8);

        lossPolicy = new MidasAliasedLossPolicyV3(address(poolMock), address(addressProviderMock));

        gateway = new MidasGatewayMockForLossPolicy();
        vault = new MidasRedemptionVaultMockForLossPolicy();
        gateway.setMidasRedemptionVault(address(vault));

        midasPhantom = new MidasPhantomTokenMock(address(gateway), address(underlying));
        otherPhantom = new NonMidasPhantomTokenMock(address(gateway), address(underlying));
        redeemer = new MidasRedeemerMockForLossPolicy(1);

        address[] memory redeemers = new address[](1);
        redeemers[0] = address(redeemer);
        gateway.setPendingRedeemers(creditAccount, redeemers);
        vault.setStatus(1, RedemptionStatus.PENDING);

        vm.mockCall(creditAccount, abi.encodeCall(ICreditAccountV3.creditManager, ()), abi.encode(creditManager));
        vm.mockCall(creditManager, abi.encodeCall(ICreditManagerV3.priceOracle, ()), abi.encode(priceOracleMock));
        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.enabledTokensMaskOf, (creditAccount)),
            abi.encode(UNDERLYING_TOKEN_MASK | MIDAS_TOKEN_MASK)
        );
        vm.mockCall(
            creditManager, abi.encodeCall(ICreditManagerV3.getTokenByMask, (MIDAS_TOKEN_MASK)), abi.encode(midasPhantom)
        );
        vm.mockCall(
            creditManager, abi.encodeCall(ICreditManagerV3.getTokenByMask, (OTHER_TOKEN_MASK)), abi.encode(otherPhantom)
        );
        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.collateralTokenByMask, (MIDAS_TOKEN_MASK)),
            abi.encode(address(midasPhantom), uint16(0))
        );
        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.collateralTokenByMask, (OTHER_TOKEN_MASK)),
            abi.encode(address(otherPhantom), uint16(0))
        );
    }

    /// @notice U:[MID-ALP-1]: Constructor and serialize work as expected
    function test_U_MID_ALP_01_constructor_and_serialize_work() public view {
        assertEq(lossPolicy.version(), 3_11, "Incorrect version");
        assertEq(lossPolicy.contractType(), "LOSS_POLICY::MIDAS_ALIASED", "Incorrect contract type");
        assertTrue(lossPolicy.checksEnabled(), "Checks should be enabled");
        assertEq(lossPolicy.pool(), address(poolMock), "Incorrect pool");

        (ILossPolicy.AccessMode mode, bool checks, address[] memory tokens, PriceFeedParams[] memory params) =
            abi.decode(lossPolicy.serialize(), (ILossPolicy.AccessMode, bool, address[], PriceFeedParams[]));
        assertEq(uint256(mode), uint256(ILossPolicy.AccessMode.Permissionless), "Incorrect serialized mode");
        assertTrue(checks, "Incorrect serialized checksEnabled");
        assertEq(tokens.length, 0, "Incorrect serialized tokens length");
        assertEq(params.length, 0, "Incorrect serialized params length");
    }

    /// @notice U:[MID-ALP-3]: Rejected pending redeemer blocks loss liquidation
    function test_U_MID_ALP_03_rejected_pending_redeemer_blocks_liquidation() public {
        vault.setStatus(1, RedemptionStatus.REJECTED);

        assertFalse(
            lossPolicy.isLiquidatableWithLoss(
                creditAccount, caller, ILossPolicy.Params({totalDebtUSD: 1, twvUSD: 0, extraData: ""})
            ),
            "Should block on REJECTED"
        );
    }

    /// @notice U:[MID-ALP-4]: Non-rejected pending redeemer does not block
    function test_U_MID_ALP_04_non_rejected_pending_redeemer_does_not_block() public {
        vault.setStatus(1, RedemptionStatus.PENDING);

        assertTrue(
            lossPolicy.isLiquidatableWithLoss(
                creditAccount, caller, ILossPolicy.Params({totalDebtUSD: 1, twvUSD: 0, extraData: ""})
            ),
            "Should allow on PENDING"
        );

        vault.setStatus(1, RedemptionStatus.APPROVED);
        assertTrue(
            lossPolicy.isLiquidatableWithLoss(
                creditAccount, caller, ILossPolicy.Params({totalDebtUSD: 1, twvUSD: 0, extraData: ""})
            ),
            "Should allow on APPROVED"
        );
    }

    /// @notice U:[MID-ALP-5]: Disabled checks ignore REJECTED status
    function test_U_MID_ALP_05_disabled_checks_ignore_rejection() public {
        vault.setStatus(1, RedemptionStatus.REJECTED);

        vm.prank(configurator);
        lossPolicy.setChecksEnabled(false);

        assertTrue(
            lossPolicy.isLiquidatableWithLoss(
                creditAccount, caller, ILossPolicy.Params({totalDebtUSD: 1, twvUSD: 0, extraData: ""})
            ),
            "Should allow when checks disabled"
        );
    }

    /// @notice U:[MID-ALP-6]: Non-Midas phantom tokens are ignored
    function test_U_MID_ALP_06_non_midas_phantom_tokens_are_ignored() public {
        vault.setStatus(1, RedemptionStatus.REJECTED);

        vm.mockCall(
            creditManager,
            abi.encodeCall(ICreditManagerV3.enabledTokensMaskOf, (creditAccount)),
            abi.encode(UNDERLYING_TOKEN_MASK | OTHER_TOKEN_MASK)
        );

        assertTrue(
            lossPolicy.isLiquidatableWithLoss(
                creditAccount, caller, ILossPolicy.Params({totalDebtUSD: 1, twvUSD: 0, extraData: ""})
            ),
            "Non-Midas phantom should not block"
        );
    }

    /// @notice U:[MID-ALP-7]: Forbidden access mode still blocks
    function test_U_MID_ALP_07_forbidden_access_mode_blocks() public {
        vm.prank(configurator);
        lossPolicy.setAccessMode(ILossPolicy.AccessMode.Forbidden);

        assertFalse(
            lossPolicy.isLiquidatableWithLoss(
                creditAccount, caller, ILossPolicy.Params({totalDebtUSD: 1, twvUSD: 0, extraData: ""})
            ),
            "Forbidden mode should block"
        );
    }
}
