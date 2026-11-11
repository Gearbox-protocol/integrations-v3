// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {
    AmountCantBeZeroException,
    ZeroAddressException
} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {AaveHorizonBridge} from "../../../../integrations/aave/AaveHorizonBridge.sol";
import {IAaveHorizonBridge} from "../../../../integrations/aave/interfaces/IAaveHorizonBridge.sol";
import {IAaveV3Pool} from "../../../../integrations/aave/interfaces/external/IAaveV3Pool.sol";
import {ICAChecker} from "../../../../integrations/common/interfaces/ICAChecker.sol";

/// @dev Unrestricted mint/burn ERC20 for aToken mocking
contract MintableToken is ERC20 {
    uint8 private immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

/// @dev Minimal Aave V3 pool mock for borrow/repay
contract AaveV3PoolMock is IAaveV3Pool {
    mapping(address => address) public aTokens;
    mapping(address => mapping(address => uint256)) public variableDebt;

    function setAToken(address asset, address aToken) external {
        aTokens[asset] = aToken;
    }

    function getReserveAToken(address asset) external view returns (address) {
        return aTokens[asset];
    }

    function supply(address, uint256, address, uint16) external pure {
        revert("not used");
    }

    function withdraw(address, uint256, address) external pure returns (uint256) {
        revert("not used");
    }

    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16, address onBehalfOf) external {
        require(interestRateMode == 2, "only variable");
        variableDebt[asset][onBehalfOf] += amount;
        IERC20(asset).transfer(msg.sender, amount);
    }

    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256)
    {
        require(interestRateMode == 2, "only variable");
        uint256 debt = variableDebt[asset][onBehalfOf];
        uint256 pay = amount > debt ? debt : amount;
        variableDebt[asset][onBehalfOf] = debt - pay;
        IERC20(asset).transferFrom(msg.sender, address(this), pay);
        return pay;
    }
}

/// @dev Moves aTokens between addresses (simulates authorizedTransfer via the manager)
contract RwaATokenManagerMock {
    function transferRwaAToken(address aToken, address from, address to, uint256 amount) external returns (bool) {
        MintableToken(aToken).burn(from, amount);
        MintableToken(aToken).mint(to, amount);
        return true;
    }
}

contract CreditAccountMock {
    bytes32 public constant contractType = "CREDIT_ACCOUNT";
    uint256 public constant version = 3_10;

    address public immutable creditManager;

    constructor(address _creditManager) {
        creditManager = _creditManager;
    }

    function approveToken(address token, address spender, uint256 amount) external {
        IERC20(token).approve(spender, amount);
    }
}

contract NonCreditAccountMock {
    bytes32 public constant contractType = "NOT_CREDIT_ACCOUNT";
}

contract CreditManagerMock {
    mapping(address => address) internal _borrowers;

    function setBorrower(address creditAccount, address borrower) external {
        _borrowers[creditAccount] = borrower;
    }

    function creditAccountInfo(address creditAccount)
        external
        view
        returns (uint256, uint256, uint128, uint128, uint256, uint16, uint64, address borrower)
    {
        borrower = _borrowers[creditAccount];
        return (0, 0, 0, 0, 0, 0, 0, borrower);
    }
}

contract ContractsRegisterMock {
    mapping(address => bool) internal _isCreditManager;

    function setCreditManager(address creditManager, bool isCreditManager_) external {
        _isCreditManager[creditManager] = isCreditManager_;
    }

    function isCreditManager(address creditManager) external view returns (bool) {
        return _isCreditManager[creditManager];
    }
}

contract MarketConfiguratorMock {
    address public immutable contractsRegister;

    constructor(address contractsRegister_) {
        contractsRegister = contractsRegister_;
    }
}

/// @title AaveHorizonBridge unit test
/// @notice U:[AHB]: Unit tests for AaveHorizonBridge
contract AaveHorizonBridgeUnitTest is Test {
    AaveHorizonBridge bridge;
    AaveV3PoolMock pool;
    RwaATokenManagerMock rwaATokenManager;
    CreditManagerMock creditManager;
    CreditAccountMock account;
    ContractsRegisterMock contractsRegister;
    MarketConfiguratorMock marketConfigurator;

    address debtToken;
    address aToken;
    address borrower;

    uint16 constant REFERRAL_CODE = 42;
    uint256 constant ATOKEN_AMOUNT = 100e18;
    uint256 constant BORROW_AMOUNT = 50e6;
    uint256 constant REPAY_AMOUNT = 50e6;

    function setUp() public {
        debtToken = address(new ERC20Mock("USDC", "USDC", 6));
        aToken = address(new MintableToken("aUSTB", "aUSTB", 18));
        borrower = makeAddr("BORROWER");

        pool = new AaveV3PoolMock();
        rwaATokenManager = new RwaATokenManagerMock();

        creditManager = new CreditManagerMock();
        contractsRegister = new ContractsRegisterMock();
        marketConfigurator = new MarketConfiguratorMock(address(contractsRegister));

        bridge =
            new AaveHorizonBridge(address(pool), address(rwaATokenManager), REFERRAL_CODE, address(marketConfigurator));

        account = new CreditAccountMock(address(creditManager));
        creditManager.setBorrower(address(account), borrower);
        contractsRegister.setCreditManager(address(creditManager), true);

        ERC20Mock(debtToken).mint(address(pool), 1_000_000e6);
    }

    /// @notice U:[AHB-1]: Constructor works as expected
    function test_U_AHB_01_constructor_works() public view {
        assertEq(bridge.contractType(), "GATEWAY::AAVE_HORIZON_BRIDGE", "Incorrect contract type");
        assertEq(bridge.version(), 3_11, "Incorrect version");
        assertEq(bridge.pool(), address(pool), "Incorrect pool");
        assertEq(bridge.rwaATokenManager(), address(rwaATokenManager), "Incorrect manager");
        assertEq(bridge.referralCode(), REFERRAL_CODE, "Incorrect referral code");
        assertEq(bridge.allowedMarketConfigurator(), address(marketConfigurator), "Incorrect market configurator");
    }

    /// @notice U:[AHB-2]: Constructor reverts on zero pool or manager
    function test_U_AHB_02_constructor_reverts_on_zero_addresses() public {
        vm.expectRevert(ZeroAddressException.selector);
        new AaveHorizonBridge(address(0), address(rwaATokenManager), REFERRAL_CODE, address(marketConfigurator));

        vm.expectRevert(ZeroAddressException.selector);
        new AaveHorizonBridge(address(pool), address(0), REFERRAL_CODE, address(marketConfigurator));

        vm.expectRevert(ICAChecker.MarketConfiguratorNotSetException.selector);
        new AaveHorizonBridge(address(pool), address(rwaATokenManager), REFERRAL_CODE, address(0));
    }

    /// @notice U:[AHB-3]: openPosition reverts for ineligible callers
    function test_U_AHB_03_open_reverts_for_ineligible_account() public {
        NonCreditAccountMock nonAccount = new NonCreditAccountMock();
        vm.prank(address(nonAccount));
        vm.expectRevert(ICAChecker.CreditAccountNotEligibleException.selector);
        bridge.openPosition(aToken, debtToken, ATOKEN_AMOUNT, BORROW_AMOUNT);

        contractsRegister.setCreditManager(address(creditManager), false);
        vm.prank(address(account));
        vm.expectRevert(ICAChecker.CreditAccountNotEligibleException.selector);
        bridge.openPosition(aToken, debtToken, ATOKEN_AMOUNT, BORROW_AMOUNT);
    }

    /// @notice U:[AHB-4]: openPosition / closePosition revert on zero amounts
    function test_U_AHB_04_reverts_on_zero_amounts() public {
        vm.startPrank(address(account));

        vm.expectRevert(AmountCantBeZeroException.selector);
        bridge.openPosition(aToken, debtToken, 0, BORROW_AMOUNT);

        vm.expectRevert(AmountCantBeZeroException.selector);
        bridge.openPosition(aToken, debtToken, ATOKEN_AMOUNT, 0);

        vm.expectRevert(AmountCantBeZeroException.selector);
        bridge.closePosition(aToken, debtToken, 0, ATOKEN_AMOUNT);

        vm.expectRevert(AmountCantBeZeroException.selector);
        bridge.closePosition(aToken, debtToken, REPAY_AMOUNT, 0);

        vm.stopPrank();
    }

    /// @notice U:[AHB-5]: openPosition / closePosition revert when owner equals the CA
    function test_U_AHB_05_reverts_when_owner_is_credit_account() public {
        creditManager.setBorrower(address(account), address(account));

        vm.prank(address(account));
        vm.expectRevert(IAaveHorizonBridge.CreditAccountOwnerIsCreditAccountException.selector);
        bridge.openPosition(aToken, debtToken, ATOKEN_AMOUNT, BORROW_AMOUNT);

        vm.prank(address(account));
        vm.expectRevert(IAaveHorizonBridge.CreditAccountOwnerIsCreditAccountException.selector);
        bridge.closePosition(aToken, debtToken, REPAY_AMOUNT, ATOKEN_AMOUNT);
    }

    /// @notice U:[AHB-6]: openPosition moves aTokens to owner and borrows to CA
    function test_U_AHB_06_open_position_works() public {
        MintableToken(aToken).mint(address(account), ATOKEN_AMOUNT);

        uint256 debtBefore = IERC20(debtToken).balanceOf(address(account));

        vm.prank(address(account));
        bridge.openPosition(aToken, debtToken, ATOKEN_AMOUNT, BORROW_AMOUNT);

        assertEq(IERC20(aToken).balanceOf(address(account)), 0, "CA should have no aTokens left");
        assertEq(IERC20(aToken).balanceOf(borrower), ATOKEN_AMOUNT, "Owner should hold aTokens");
        assertEq(IERC20(debtToken).balanceOf(address(account)), debtBefore + BORROW_AMOUNT, "CA should receive borrow");
        assertEq(pool.variableDebt(debtToken, borrower), BORROW_AMOUNT, "Owner should hold debt");
    }

    /// @notice U:[AHB-7]: closePosition repays owner debt and returns aTokens to CA
    function test_U_AHB_07_close_position_works() public {
        MintableToken(aToken).mint(address(account), ATOKEN_AMOUNT);
        vm.prank(address(account));
        bridge.openPosition(aToken, debtToken, ATOKEN_AMOUNT, BORROW_AMOUNT);

        account.approveToken(debtToken, address(bridge), REPAY_AMOUNT);

        vm.prank(address(account));
        bridge.closePosition(aToken, debtToken, REPAY_AMOUNT, ATOKEN_AMOUNT);

        assertEq(pool.variableDebt(debtToken, borrower), 0, "Owner debt should be repaid");
        assertEq(IERC20(aToken).balanceOf(borrower), 0, "Owner should have no aTokens");
        assertEq(IERC20(aToken).balanceOf(address(account)), ATOKEN_AMOUNT, "CA should receive aTokens");
        assertEq(IERC20(debtToken).allowance(address(bridge), address(pool)), 0, "Repay allowance should be cleared");
    }
}
