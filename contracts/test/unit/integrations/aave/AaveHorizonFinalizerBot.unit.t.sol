// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {
    DECREASE_DEBT_PERMISSION,
    EXTERNAL_CALLS_PERMISSION,
    ICreditFacadeV3Multicall,
    UPDATE_QUOTA_PERMISSION,
    WITHDRAW_COLLATERAL_PERMISSION
} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {
    CollateralCalcTask,
    CollateralDebtData
} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {
    AmountCantBeZeroException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AaveHorizonFinalizerBot} from "../../../../integrations/aave/AaveHorizonFinalizerBot.sol";
import {IAaveHorizonBridgeAdapter} from "../../../../integrations/aave/interfaces/IAaveHorizonBridgeAdapter.sol";
import {IAaveHorizonFinalizerBot} from "../../../../integrations/aave/interfaces/IAaveHorizonFinalizerBot.sol";
import {IAaveV3Pool} from "../../../../integrations/aave/interfaces/external/IAaveV3Pool.sol";
import {IAaveV3PoolAdapter} from "../../../../integrations/aave/interfaces/IAaveV3PoolAdapter.sol";

contract CreditAccountMock {
    address public immutable creditManager;

    constructor(address creditManager_) {
        creditManager = creditManager_;
    }
}

contract CreditFacadeMock {
    MultiCall[] internal _lastCalls;

    function botMulticall(address, MultiCall[] calldata calls) external {
        delete _lastCalls;
        for (uint256 i; i < calls.length; ++i) {
            _lastCalls.push(calls[i]);
        }
    }

    function lastCalls() external view returns (MultiCall[] memory) {
        return _lastCalls;
    }
}

contract CreditManagerMock {
    address public creditFacade;
    address public underlying;
    mapping(address => address) public contractToAdapter;

    uint256 public debt;
    uint256 public accruedInterest;
    uint256 public accruedFees;
    address public borrower;

    function setFacade(address facade_) external {
        creditFacade = facade_;
    }

    function setUnderlying(address underlying_) external {
        underlying = underlying_;
    }

    function setAdapter(address target, address adapter) external {
        contractToAdapter[target] = adapter;
    }

    function setDebt(uint256 debt_, uint256 interest_, uint256 fees_) external {
        debt = debt_;
        accruedInterest = interest_;
        accruedFees = fees_;
    }

    function setBorrower(address borrower_) external {
        borrower = borrower_;
    }

    function calcDebtAndCollateral(address, CollateralCalcTask) external view returns (CollateralDebtData memory cdd) {
        cdd.debt = debt;
        cdd.accruedInterest = accruedInterest;
        cdd.accruedFees = accruedFees;
    }

    function creditAccountInfo(address)
        external
        view
        returns (uint256, uint256, uint128, uint128, uint256, uint16, uint64, address borrower_)
    {
        return (debt, 0, 0, 0, 0, 0, 0, borrower);
    }
}

/// @title AaveHorizonFinalizerBot unit test
/// @notice U:[AHFB]: Unit tests for AaveHorizonFinalizerBot
contract AaveHorizonFinalizerBotUnitTest is Test {
    AaveHorizonFinalizerBot bot;
    CreditManagerMock creditManager;
    CreditFacadeMock creditFacade;
    CreditAccountMock creditAccount;

    address pool;
    address bridge;
    address poolAdapter;
    address bridgeAdapter;
    address rwaToken;
    address aToken;
    address underlying;
    address borrower;
    address phantom;

    uint256 constant TOTAL_DEBT = 100e6;
    uint256 constant INTEREST = 1e6;
    uint256 constant FEES = 1e6;

    function setUp() public {
        pool = makeAddr("POOL");
        bridge = makeAddr("BRIDGE");
        poolAdapter = makeAddr("POOL_ADAPTER");
        bridgeAdapter = makeAddr("BRIDGE_ADAPTER");
        borrower = makeAddr("BORROWER");
        phantom = makeAddr("PHANTOM");

        rwaToken = address(new ERC20Mock("USTB", "USTB", 18));
        aToken = makeAddr("A_TOKEN");
        underlying = address(new ERC20Mock("USDC", "USDC", 6));

        creditFacade = new CreditFacadeMock();
        creditManager = new CreditManagerMock();
        creditManager.setFacade(address(creditFacade));
        creditManager.setUnderlying(underlying);
        creditManager.setAdapter(pool, poolAdapter);
        creditManager.setAdapter(bridge, bridgeAdapter);
        creditManager.setBorrower(borrower);
        creditManager.setDebt(TOTAL_DEBT, INTEREST, FEES);

        creditAccount = new CreditAccountMock(address(creditManager));

        vm.mockCall(pool, abi.encodeCall(IAaveV3Pool.getReserveAToken, (rwaToken)), abi.encode(aToken));

        bot = new AaveHorizonFinalizerBot(pool, bridge);
    }

    function _emptyClaim() internal pure returns (MultiCall memory) {
        return MultiCall({target: address(0), callData: ""});
    }

    function _claimCall() internal pure returns (MultiCall memory) {
        return MultiCall({target: address(uint160(uint256(keccak256("CLAIM_TARGET")))), callData: hex"deadbeef"});
    }

    /// @notice U:[AHFB-1]: Constructor works as expected
    function test_U_AHFB_01_constructor_works() public view {
        assertEq(bot.contractType(), "BOT::AAVE_HORIZON_FINALIZER");
        assertEq(bot.version(), 3_11);
        assertEq(bot.pool(), pool);
        assertEq(bot.bridge(), bridge);
        assertEq(
            bot.requiredPermissions(),
            EXTERNAL_CALLS_PERMISSION | DECREASE_DEBT_PERMISSION | WITHDRAW_COLLATERAL_PERMISSION
                | UPDATE_QUOTA_PERMISSION
        );

        (address pool_, address bridge_) = abi.decode(bot.serialize(), (address, address));
        assertEq(pool_, pool);
        assertEq(bridge_, bridge);
    }

    /// @notice U:[AHFB-2]: Constructor reverts on zero addresses
    function test_U_AHFB_02_constructor_reverts_on_zero_addresses() public {
        vm.expectRevert(ZeroAddressException.selector);
        new AaveHorizonFinalizerBot(address(0), bridge);

        vm.expectRevert(ZeroAddressException.selector);
        new AaveHorizonFinalizerBot(pool, address(0));
    }

    /// @notice U:[AHFB-3]: finalizeOpen without claim works
    function test_U_AHFB_03_finalizeOpen_without_claim() public {
        ERC20Mock(rwaToken).mint(address(creditAccount), 50e18);

        bot.finalizeOpen(address(creditAccount), rwaToken, _emptyClaim(), address(0));

        MultiCall[] memory calls = creditFacade.lastCalls();
        assertEq(calls.length, 4, "Incorrect call count");

        assertEq(calls[0].target, poolAdapter, "call0 target");
        assertEq(calls[0].callData, abi.encodeCall(IAaveV3PoolAdapter.supplyDiff, (rwaToken, 0)), "call0 data");

        assertEq(calls[1].target, bridgeAdapter, "call1 target");
        assertEq(
            calls[1].callData,
            abi.encodeCall(
                IAaveHorizonBridgeAdapter.openPositionDiff, (aToken, underlying, 0, TOTAL_DEBT + INTEREST + FEES)
            ),
            "call1 data"
        );

        assertEq(calls[2].target, address(creditFacade), "call2 target");
        assertEq(
            calls[2].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.updateQuota, (rwaToken, type(int96).min, 0)),
            "call2 data"
        );

        assertEq(calls[3].target, address(creditFacade), "call3 target");
        assertEq(
            calls[3].callData, abi.encodeCall(ICreditFacadeV3Multicall.decreaseDebt, (type(uint256).max)), "call3 data"
        );
    }

    /// @notice U:[AHFB-4]: finalizeOpen with claim uses phantom quota
    function test_U_AHFB_04_finalizeOpen_with_claim() public {
        MultiCall memory claim = _claimCall();

        bot.finalizeOpen(address(creditAccount), rwaToken, claim, phantom);

        MultiCall[] memory calls = creditFacade.lastCalls();
        assertEq(calls.length, 5, "Incorrect call count");
        assertEq(calls[0].target, claim.target, "claim target");
        assertEq(calls[0].callData, claim.callData, "claim data");
        assertEq(
            calls[3].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.updateQuota, (phantom, type(int96).min, 0)),
            "phantom quota"
        );
    }

    /// @notice U:[AHFB-5]: finalizeOpen reverts on invalid claim/phantom pair
    function test_U_AHFB_05_finalizeOpen_reverts_on_invalid_claim_phantom_pair() public {
        vm.expectRevert(IAaveHorizonFinalizerBot.InvalidClaimPhantomPairException.selector);
        bot.finalizeOpen(address(creditAccount), rwaToken, _claimCall(), address(0));

        vm.expectRevert(IAaveHorizonFinalizerBot.InvalidClaimPhantomPairException.selector);
        bot.finalizeOpen(address(creditAccount), rwaToken, _emptyClaim(), phantom);
    }

    /// @notice U:[AHFB-6]: finalizeOpen reverts on zero RWA (no claim) or zero debt
    function test_U_AHFB_06_finalizeOpen_reverts_on_zero_rwa_or_debt() public {
        vm.expectRevert(AmountCantBeZeroException.selector);
        bot.finalizeOpen(address(creditAccount), rwaToken, _emptyClaim(), address(0));

        ERC20Mock(rwaToken).mint(address(creditAccount), 1);
        creditManager.setDebt(0, 0, 0);
        vm.expectRevert(AmountCantBeZeroException.selector);
        bot.finalizeOpen(address(creditAccount), rwaToken, _emptyClaim(), address(0));
    }

    /// @notice U:[AHFB-7]: finalizeOpen reverts when adapters are missing
    function test_U_AHFB_07_finalizeOpen_reverts_when_adapter_missing() public {
        ERC20Mock(rwaToken).mint(address(creditAccount), 1e18);
        creditManager.setAdapter(pool, address(0));

        vm.expectRevert(IAaveHorizonFinalizerBot.AdapterNotFoundException.selector);
        bot.finalizeOpen(address(creditAccount), rwaToken, _emptyClaim(), address(0));
    }

    /// @notice U:[AHFB-8]: finalizeClose without claim works
    function test_U_AHFB_08_finalizeClose_without_claim() public {
        bot.finalizeClose(address(creditAccount), _emptyClaim(), address(0));

        MultiCall[] memory calls = creditFacade.lastCalls();
        assertEq(calls.length, 2, "Incorrect call count");
        assertEq(
            calls[0].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.decreaseDebt, (type(uint256).max)),
            "decreaseDebt"
        );
        assertEq(
            calls[1].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.withdrawCollateral, (underlying, type(uint256).max, borrower)),
            "withdraw"
        );
    }

    /// @notice U:[AHFB-9]: finalizeClose with claim zeros phantom quota
    function test_U_AHFB_09_finalizeClose_with_claim() public {
        MultiCall memory claim = _claimCall();

        bot.finalizeClose(address(creditAccount), claim, phantom);

        MultiCall[] memory calls = creditFacade.lastCalls();
        assertEq(calls.length, 4, "Incorrect call count");
        assertEq(calls[0].target, claim.target, "claim target");
        assertEq(
            calls[1].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.updateQuota, (phantom, type(int96).min, 0)),
            "phantom quota"
        );
        assertEq(
            calls[2].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.decreaseDebt, (type(uint256).max)),
            "decreaseDebt"
        );
        assertEq(
            calls[3].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.withdrawCollateral, (underlying, type(uint256).max, borrower)),
            "withdraw"
        );
    }

    /// @notice U:[AHFB-10]: finalizeClose reverts on invalid claim/phantom pair
    function test_U_AHFB_10_finalizeClose_reverts_on_invalid_claim_phantom_pair() public {
        vm.expectRevert(IAaveHorizonFinalizerBot.InvalidClaimPhantomPairException.selector);
        bot.finalizeClose(address(creditAccount), _claimCall(), address(0));

        vm.expectRevert(IAaveHorizonFinalizerBot.InvalidClaimPhantomPairException.selector);
        bot.finalizeClose(address(creditAccount), _emptyClaim(), phantom);
    }
}
