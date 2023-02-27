// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "@gearbox-protocol/core-v2/contracts/interfaces/external/IWETH.sol";

import {CreditFacade} from "@gearbox-protocol/core-v2/contracts/credit/CreditFacade.sol";
import {CreditManager} from "@gearbox-protocol/core-v2/contracts/credit/CreditManager.sol";

import {CreditAccount} from "@gearbox-protocol/core-v2/contracts/credit/CreditAccount.sol";
import {AccountFactory} from "@gearbox-protocol/core-v2/contracts/core/AccountFactory.sol";

import {ICreditFacade, ICreditFacadeExtended} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import {
    ICreditManagerV2,
    ICreditManagerV2Events,
    ClosureAction
} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";
import {
    ICreditFacadeEvents,
    ICreditFacadeExceptions
} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditFacade.sol";
import {IDegenNFT, IDegenNFTExceptions} from "@gearbox-protocol/core-v2/contracts/interfaces/IDegenNFT.sol";

// DATA
import {MultiCall, MultiCallOps} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {Balance} from "@gearbox-protocol/core-v2/contracts/libraries/Balances.sol";

import {
    CreditFacadeMulticaller,
    CreditFacadeCalls
} from "@gearbox-protocol/core-v2/contracts/multicall/CreditFacadeCalls.sol";

// CONSTANTS

import {LEVERAGE_DECIMALS} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import {PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/PercentageMath.sol";

// TESTS

import "../lib/constants.sol";
import {BalanceHelper} from "../helpers/BalanceHelper.sol";
import {CreditFacadeTestHelper} from "../helpers/CreditFacadeTestHelper.sol";

// EXCEPTIONS
import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";
import {ICreditManagerV2Exceptions} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";

// MOCKS
import {AdapterMock} from "@gearbox-protocol/core-v2/contracts/test/mocks/adapters/AdapterMock.sol";
import {TargetContractMock} from "@gearbox-protocol/core-v2/contracts/test/mocks/adapters/TargetContractMock.sol";

import {UniswapV2Mock} from "../mocks/integrations/UniswapV2Mock.sol";
import {UniswapV2Adapter} from "../../adapters/uniswap/UniswapV2.sol";

// SUITES
import {TokensTestSuite, Tokens} from "../suites/TokensTestSuite.sol";
import {CreditFacadeTestSuite} from "@gearbox-protocol/core-v2/contracts/test/suites/CreditFacadeTestSuite.sol";
import {CreditConfig} from "../config/CreditConfig.sol";

uint256 constant WETH_TEST_AMOUNT = 5 * WAD;
uint16 constant REFERRAL_CODE = 23;

/// @title CreditFacadeTest
/// @notice Designed for unit test purposes only
contract CreditFacadeTest is
    DSTest,
    BalanceHelper,
    CreditFacadeTestHelper,
    ICreditManagerV2Events,
    ICreditFacadeEvents,
    ICreditFacadeExceptions
{
    using CreditFacadeCalls for CreditFacadeMulticaller;

    AccountFactory accountFactory;

    TargetContractMock targetMock;
    AdapterMock adapterMock;

    function setUp() public {
        tokenTestSuite = new TokensTestSuite();
        tokenTestSuite.topUpWETH{value: 100 * WAD}();

        CreditConfig creditConfig = new CreditConfig(
            tokenTestSuite,
            Tokens.DAI
        );

        cft = new CreditFacadeTestSuite(creditConfig);

        underlying = tokenTestSuite.addressOf(Tokens.DAI);
        creditManager = cft.creditManager();
        creditFacade = cft.creditFacade();
        creditConfigurator = cft.creditConfigurator();

        accountFactory = cft.af();

        targetMock = new TargetContractMock();
        adapterMock = new AdapterMock(
            address(creditManager),
            address(targetMock)
        );

        evm.label(address(adapterMock), "AdapterMock");
        evm.label(address(targetMock), "TargetContractMock");
    }

    ///
    ///
    ///  HELPERS
    ///
    ///

    function _prepareForWETHTest() internal {
        _prepareForWETHTest(USER);
    }

    function _prepareForWETHTest(address tester) internal {
        address weth = tokenTestSuite.addressOf(Tokens.WETH);

        evm.startPrank(tester);
        if (tester.balance > 0) {
            IWETH(weth).deposit{value: tester.balance}();
        }

        IERC20(weth).transfer(address(this), tokenTestSuite.balanceOf(Tokens.WETH, tester));

        evm.stopPrank();
        expectBalance(Tokens.WETH, tester, 0);

        evm.deal(tester, WETH_TEST_AMOUNT);
    }

    function _checkForWETHTest() internal {
        _checkForWETHTest(USER);
    }

    function _checkForWETHTest(address tester) internal {
        expectBalance(Tokens.WETH, tester, WETH_TEST_AMOUNT);

        expectEthBalance(tester, 0);
    }

    function _prepareMockCall() internal returns (bytes memory callData) {
        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(address(targetMock), address(adapterMock));

        callData = abi.encodeWithSignature("hello(string)", "world");
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [FA-55]: liquidateCreditAccount works in pause for pausable liquidators
    function test_FA_55_liquidateCreditAccount_works_in_pause_for_pausable_liquidators() public {
        UniswapV2Mock uniswapMock = new UniswapV2Mock();

        uniswapMock.setRate(
            tokenTestSuite.addressOf(Tokens.DAI), tokenTestSuite.addressOf(Tokens.WETH), RAY / DAI_WETH_RATE
        );

        tokenTestSuite.mint(tokenTestSuite.addressOf(Tokens.WETH), address(uniswapMock), DAI_ACCOUNT_AMOUNT);

        UniswapV2Adapter adapter;

        {
            address[] memory connectors = new address[](2);

            connectors[0] = tokenTestSuite.addressOf(Tokens.USDC);
            connectors[1] = tokenTestSuite.addressOf(Tokens.USDT);

            adapter = new UniswapV2Adapter(
                address(creditManager),
                address(uniswapMock),
                connectors
            );
        }

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(address(uniswapMock), address(adapter));

        uint256 accountAmount = DAI_ACCOUNT_AMOUNT;

        tokenTestSuite.mint(underlying, USER, accountAmount);

        MultiCall[] memory calls = multicallBuilder(
            MultiCall({
                target: address(creditFacade),
                callData: abi.encodeWithSelector(
                    ICreditFacadeExtended.addCollateral.selector,
                    USER,
                    tokenTestSuite.addressOf(Tokens.DAI),
                    DAI_ACCOUNT_AMOUNT
                    )
            }),
            MultiCall({
                target: address(adapter),
                callData: abi.encodeWithSelector(
                    UniswapV2Adapter.swapAllTokensForTokens.selector,
                    0,
                    arrayOf(tokenTestSuite.addressOf(Tokens.DAI), tokenTestSuite.addressOf(Tokens.WETH)),
                    block.timestamp
                    )
            })
        );

        tokenTestSuite.approve(Tokens.DAI, USER, address(creditManager));

        evm.prank(USER);
        creditFacade.openCreditAccountMulticall(accountAmount, USER, calls, 0);

        address creditAccount = creditManager.getCreditAccountOrRevert(USER);

        uint256 balance = IERC20(underlying).balanceOf(creditAccount);

        assertEq(balance, 1, "Incorrect underlying balance");

        evm.label(creditAccount, "creditAccount");
        {
            (
                uint16 _feeInterest,
                uint16 _feeLiquidation,
                uint16 _liquidationDiscount,
                uint16 _feeLiquidationExpired,
                uint16 _liquidationPremiumExpired
            ) = creditManager.fees();

            // set LT to 1
            evm.prank(CONFIGURATOR);
            creditConfigurator.setFees(
                _feeInterest,
                _liquidationDiscount - 1,
                PERCENTAGE_FACTOR - _liquidationDiscount,
                _feeLiquidationExpired,
                _liquidationPremiumExpired
            );

            evm.prank(CONFIGURATOR);
            creditConfigurator.setFees(
                _feeInterest,
                _feeLiquidation,
                PERCENTAGE_FACTOR - _liquidationDiscount,
                _feeLiquidationExpired,
                _liquidationPremiumExpired
            );
        }

        uint256 hf = creditFacade.calcCreditAccountHealthFactor(creditAccount);
        assertTrue(hf < PERCENTAGE_FACTOR, "Incorrect health factor");

        calls = multicallBuilder(
            MultiCall({
                target: address(adapter),
                callData: abi.encodeWithSelector(
                    UniswapV2Adapter.swapAllTokensForTokens.selector,
                    0,
                    arrayOf(tokenTestSuite.addressOf(Tokens.WETH), tokenTestSuite.addressOf(Tokens.DAI)),
                    block.timestamp
                    )
            })
        );

        evm.prank(CONFIGURATOR);
        CreditManager(address(creditManager)).pause();

        evm.roll(block.number + 1);

        /// Check that it reverts when paused
        evm.prank(LIQUIDATOR);
        evm.expectRevert("Pausable: paused");
        creditFacade.liquidateCreditAccount(USER, LIQUIDATOR, 0, false, calls);

        evm.prank(CONFIGURATOR);
        creditConfigurator.addEmergencyLiquidator(LIQUIDATOR);

        // We need extra balamce for Liquidator to cover Uniswap fees
        // totalAmount in WETH = 2 * DAI_ACCOUNT_AMOUNT / DAI_WETH_RAY * (1 - fee)
        // so, after exchnage it would drop for 2 * (1 -fee)
        tokenTestSuite.mint(
            tokenTestSuite.addressOf(Tokens.DAI),
            LIQUIDATOR,
            (DAI_ACCOUNT_AMOUNT * 2 * (1000 - uniswapMock.FEE_MULTIPLIER())) / 1000
        );

        tokenTestSuite.approve(underlying, LIQUIDATOR, address(creditManager));

        evm.prank(LIQUIDATOR);
        creditFacade.liquidateCreditAccount(USER, LIQUIDATOR, 0, false, calls);

        assertTrue(!creditFacade.hasOpenedCreditAccount(USER), "USER still has credit account");
    }
}
