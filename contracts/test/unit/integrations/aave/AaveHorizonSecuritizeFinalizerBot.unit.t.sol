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

import {AaveHorizonSecuritizeFinalizerBot} from "../../../../integrations/aave/AaveHorizonSecuritizeFinalizerBot.sol";
import {IAaveHorizonBridgeAdapter} from "../../../../integrations/aave/interfaces/IAaveHorizonBridgeAdapter.sol";
import {IAaveHorizonFinalizerBot} from "../../../../integrations/aave/interfaces/IAaveHorizonFinalizerBot.sol";
import {IAaveV3Pool} from "../../../../integrations/aave/interfaces/external/IAaveV3Pool.sol";
import {IAaveV3PoolAdapter} from "../../../../integrations/aave/interfaces/IAaveV3PoolAdapter.sol";
import {IInvestorAware} from "../../../../integrations/aave/interfaces/external/IInvestorAware.sol";
import {IERC4626Adapter} from "../../../../integrations/erc4626/interfaces/IERC4626Adapter.sol";

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

/// @title AaveHorizonSecuritizeFinalizerBot unit test
/// @notice U:[AHSFB]: Unit tests for AaveHorizonSecuritizeFinalizerBot
contract AaveHorizonSecuritizeFinalizerBotUnitTest is Test {
    AaveHorizonSecuritizeFinalizerBot bot;
    CreditManagerMock creditManager;
    CreditFacadeMock creditFacade;
    CreditAccountMock creditAccount;

    address pool;
    address bridge;
    address poolAdapter;
    address bridgeAdapter;
    address wrapperAdapter;
    address wallet;
    address investor;
    address rwaToken;
    address aToken;
    address underlying;
    address debtAsset;
    address phantom;

    uint256 constant TOTAL_DEBT = 100e6;
    uint256 constant INTEREST = 1e6;
    uint256 constant FEES = 1e6;

    function setUp() public {
        pool = makeAddr("POOL");
        bridge = makeAddr("BRIDGE");
        poolAdapter = makeAddr("POOL_ADAPTER");
        bridgeAdapter = makeAddr("BRIDGE_ADAPTER");
        wrapperAdapter = makeAddr("WRAPPER_ADAPTER");
        wallet = makeAddr("WALLET");
        investor = makeAddr("INVESTOR");
        phantom = makeAddr("PHANTOM");

        rwaToken = address(new ERC20Mock("USTB", "USTB", 18));
        aToken = makeAddr("A_TOKEN");
        underlying = address(new ERC20Mock("sdUSDC", "sdUSDC", 6));
        debtAsset = address(new ERC20Mock("USDC", "USDC", 6));

        creditFacade = new CreditFacadeMock();
        creditManager = new CreditManagerMock();
        creditManager.setFacade(address(creditFacade));
        creditManager.setUnderlying(underlying);
        creditManager.setAdapter(pool, poolAdapter);
        creditManager.setAdapter(bridge, bridgeAdapter);
        creditManager.setAdapter(underlying, wrapperAdapter);
        creditManager.setBorrower(wallet);
        creditManager.setDebt(TOTAL_DEBT, INTEREST, FEES);

        creditAccount = new CreditAccountMock(address(creditManager));

        vm.mockCall(pool, abi.encodeCall(IAaveV3Pool.getReserveAToken, (rwaToken)), abi.encode(aToken));
        vm.mockCall(wrapperAdapter, abi.encodeCall(IERC4626Adapter.asset, ()), abi.encode(debtAsset));
        vm.mockCall(underlying, abi.encodeWithSignature("asset()"), abi.encode(debtAsset));
        vm.mockCall(wallet, abi.encodeCall(IInvestorAware.getInvestor, ()), abi.encode(investor));

        bot = new AaveHorizonSecuritizeFinalizerBot(pool, bridge);
    }

    function _emptyClaim() internal pure returns (MultiCall memory) {
        return MultiCall({target: address(0), callData: ""});
    }

    function _claimCall() internal pure returns (MultiCall memory) {
        return MultiCall({target: address(uint160(uint256(keccak256("CLAIM_TARGET")))), callData: hex"deadbeef"});
    }

    /// @notice U:[AHSFB-1]: Constructor works as expected
    function test_U_AHSFB_01_constructor_works() public view {
        assertEq(bot.contractType(), "BOT::AAVE_HORIZON_SECURITIZE");
        assertEq(bot.version(), 3_11);
        assertEq(bot.pool(), pool);
        assertEq(bot.bridge(), bridge);
        assertEq(
            bot.requiredPermissions(),
            EXTERNAL_CALLS_PERMISSION | DECREASE_DEBT_PERMISSION | WITHDRAW_COLLATERAL_PERMISSION
                | UPDATE_QUOTA_PERMISSION
        );
    }

    /// @notice U:[AHSFB-2]: finalizeOpen wraps vault asset and borrows it from Aave
    function test_U_AHSFB_02_finalizeOpen_wraps_and_borrows_asset() public {
        ERC20Mock(rwaToken).mint(address(creditAccount), 50e18);

        bot.finalizeOpen(address(creditAccount), rwaToken, _emptyClaim(), address(0));

        MultiCall[] memory calls = creditFacade.lastCalls();
        assertEq(calls.length, 5, "Incorrect call count");
        assertEq(calls[0].callData, abi.encodeCall(IAaveV3PoolAdapter.supplyDiff, (rwaToken, 0)), "supply");
        assertEq(
            calls[1].callData,
            abi.encodeCall(
                IAaveHorizonBridgeAdapter.openPositionDiff, (aToken, debtAsset, 0, TOTAL_DEBT + INTEREST + FEES)
            ),
            "open"
        );
        assertEq(calls[2].target, wrapperAdapter, "wrap target");
        assertEq(calls[2].callData, abi.encodeCall(IERC4626Adapter.depositDiff, (0)), "wrap");
        assertEq(
            calls[3].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.updateQuota, (rwaToken, type(int96).min, 0)),
            "quota"
        );
        assertEq(calls[4].callData, abi.encodeCall(ICreditFacadeV3Multicall.decreaseDebt, (type(uint256).max)), "repay");
    }

    /// @notice U:[AHSFB-3]: finalizeClose deposits exact debt and withdraws leftover asset to investor
    function test_U_AHSFB_03_finalizeClose_wraps_and_withdraws_to_investor() public {
        bot.finalizeClose(address(creditAccount), _emptyClaim(), address(0));

        MultiCall[] memory calls = creditFacade.lastCalls();
        assertEq(calls.length, 3, "Incorrect call count");
        assertEq(calls[0].target, wrapperAdapter, "wrap target");
        assertEq(
            calls[0].callData,
            abi.encodeCall(IERC4626Adapter.deposit, (TOTAL_DEBT + INTEREST + FEES, address(0))),
            "wrap"
        );
        assertEq(calls[1].callData, abi.encodeCall(ICreditFacadeV3Multicall.decreaseDebt, (type(uint256).max)), "repay");
        assertEq(
            calls[2].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.withdrawCollateral, (debtAsset, type(uint256).max, investor)),
            "withdraw to investor"
        );
    }

    /// @notice U:[AHSFB-4]: finalizeClose with claim zeros phantom quota then wraps
    function test_U_AHSFB_04_finalizeClose_with_claim() public {
        MultiCall memory claim = _claimCall();

        bot.finalizeClose(address(creditAccount), claim, phantom);

        MultiCall[] memory calls = creditFacade.lastCalls();
        assertEq(calls.length, 5, "Incorrect call count");
        assertEq(calls[0].target, claim.target, "claim");
        assertEq(
            calls[1].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.updateQuota, (phantom, type(int96).min, 0)),
            "phantom quota"
        );
        assertEq(
            calls[2].callData,
            abi.encodeCall(IERC4626Adapter.deposit, (TOTAL_DEBT + INTEREST + FEES, address(0))),
            "wrap"
        );
        assertEq(
            calls[4].callData,
            abi.encodeCall(ICreditFacadeV3Multicall.withdrawCollateral, (debtAsset, type(uint256).max, investor)),
            "withdraw to investor"
        );
    }

    /// @notice U:[AHSFB-5]: finalizeOpen reverts when wrapper adapter is missing
    function test_U_AHSFB_05_finalizeOpen_reverts_when_wrapper_missing() public {
        creditManager.setAdapter(underlying, address(0));
        ERC20Mock(rwaToken).mint(address(creditAccount), 1e18);

        vm.expectRevert(IAaveHorizonFinalizerBot.AdapterNotFoundException.selector);
        bot.finalizeOpen(address(creditAccount), rwaToken, _emptyClaim(), address(0));
    }

    /// @notice U:[AHSFB-6]: finalizeClose reverts when investor is zero
    function test_U_AHSFB_06_finalizeClose_reverts_on_zero_investor() public {
        vm.mockCall(wallet, abi.encodeCall(IInvestorAware.getInvestor, ()), abi.encode(address(0)));

        vm.expectRevert(ZeroAddressException.selector);
        bot.finalizeClose(address(creditAccount), _emptyClaim(), address(0));
    }

    /// @notice U:[AHSFB-7]: finalizeOpen reverts on invalid claim/phantom pair
    function test_U_AHSFB_07_finalizeOpen_reverts_on_invalid_claim_phantom_pair() public {
        vm.expectRevert(IAaveHorizonFinalizerBot.InvalidClaimPhantomPairException.selector);
        bot.finalizeOpen(address(creditAccount), rwaToken, _claimCall(), address(0));

        vm.expectRevert(IAaveHorizonFinalizerBot.InvalidClaimPhantomPairException.selector);
        bot.finalizeOpen(address(creditAccount), rwaToken, _emptyClaim(), phantom);
    }

    /// @notice U:[AHSFB-8]: finalizeOpen reverts on zero RWA or zero debt
    function test_U_AHSFB_08_finalizeOpen_reverts_on_zero_rwa_or_debt() public {
        vm.expectRevert(AmountCantBeZeroException.selector);
        bot.finalizeOpen(address(creditAccount), rwaToken, _emptyClaim(), address(0));

        ERC20Mock(rwaToken).mint(address(creditAccount), 1);
        creditManager.setDebt(0, 0, 0);
        vm.expectRevert(AmountCantBeZeroException.selector);
        bot.finalizeOpen(address(creditAccount), rwaToken, _emptyClaim(), address(0));
    }
}
