// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CurveV1Adapter2Assets} from "../../../adapters/curve/CurveV1_2.sol";
import {CurveV1Adapter3Assets} from "../../../adapters/curve/CurveV1_3.sol";
import {CurveV1Adapter4Assets} from "../../../adapters/curve/CurveV1_4.sol";
import {CurveV1StETHPoolGateway} from "../../../adapters/curve/CurveV1_stETHGateway.sol";
import {CurveV1AdapterStETH} from "../../../adapters/curve/CurveV1_stETH.sol";
import {ICurveV1Adapter, ICurveV1AdapterExceptions} from "../../../interfaces/curve/ICurveV1Adapter.sol";
import {ICurvePoolStETH} from "../../../integrations/curve/ICurvePoolStETH.sol";
import {ICurvePool} from "../../../integrations/curve/ICurvePool.sol";
import {ICRVToken} from "../../../integrations/curve/ICRVToken.sol";
import {ICreditManagerV2} from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";
import {CurveV1StETHMock} from "../../mocks/integrations/CurveV1StETHMock.sol";

import {CurveV1Mock} from "../../mocks/integrations/CurveV1Mock.sol";
import {CurveV1MetapoolMock} from "../../mocks/integrations/CurveV1MetapoolMock.sol";
import {CurveV1Mock_2Assets} from "../../mocks/integrations/CurveV1Mock_2Assets.sol";
import {CurveV1Mock_3Assets} from "../../mocks/integrations/CurveV1Mock_3Assets.sol";
import {CurveV1Mock_4Assets} from "../../mocks/integrations/CurveV1Mock_4Assets.sol";

import {Tokens} from "../../config/Tokens.sol";

import {CurveLP2PriceFeed} from "../../../oracles/curve/CurveLP2PriceFeed.sol";
import {CurveLP3PriceFeed} from "../../../oracles/curve/CurveLP3PriceFeed.sol";
import {CurveLP4PriceFeed} from "../../../oracles/curve/CurveLP4PriceFeed.sol";

// TEST
import "../../lib/constants.sol";

import {AdapterTestHelper} from "../AdapterTestHelper.sol";

uint256 constant DAI_TO_LP = DAI_ACCOUNT_AMOUNT / 4;
uint256 constant USDC_TO_LP = USDC_ACCOUNT_AMOUNT / 3;
uint256 constant USDT_TO_LP = USDT_ACCOUNT_AMOUNT / 5;
uint256 constant LINK_TO_LP = LINK_ACCOUNT_AMOUNT / 5;

/// @title CurveV1AdapterHelper
/// @notice Designed for unit test purposes only
contract CurveV1AdapterHelper is DSTest, AdapterTestHelper, ICurveV1AdapterExceptions {
    address internal _curveV1MockAddr;
    address internal _adapterAddr;

    address internal _curveV1stETHMockAddr;
    address internal _curveV1stETHPoolGateway;
    address internal _adapterStETHAddr;

    address internal _basePoolAddr;

    Tokens[4] internal poolTkns;
    Tokens[4] internal underlyingPoolTkns;
    address internal lpToken;

    function _setupCurveSuite(uint256 nCoins) internal {
        _setUp();

        poolTkns = [Tokens.cDAI, Tokens.cUSDC, Tokens.cUSDT, Tokens.cLINK];
        underlyingPoolTkns = [Tokens.DAI, Tokens.USDC, Tokens.USDT, Tokens.LINK];

        address[] memory curvePoolTokens = getPoolTokens(nCoins);
        address[] memory curvePoolUnderlyings = getUnderlyingPoolTokens(nCoins);

        address _priceFeed;

        if (nCoins == 2) {
            _curveV1MockAddr = address(new CurveV1Mock_2Assets(curvePoolTokens, curvePoolUnderlyings));

            _priceFeed = address(
                new CurveLP2PriceFeed(
                    address(cft.addressProvider()),
                    _curveV1MockAddr,
                    cft.priceOracle().priceFeeds(curvePoolTokens[0]),
                    cft.priceOracle().priceFeeds(curvePoolTokens[1]),
                    "CurveLP2PriceFeed"
                )
            );
        } else if (nCoins == 3) {
            _curveV1MockAddr = address(new CurveV1Mock_3Assets(curvePoolTokens, curvePoolUnderlyings));

            _priceFeed = address(
                new CurveLP3PriceFeed(
                    address(cft.addressProvider()),
                    _curveV1MockAddr,
                    cft.priceOracle().priceFeeds(curvePoolTokens[0]),
                    cft.priceOracle().priceFeeds(curvePoolTokens[1]),
                    cft.priceOracle().priceFeeds(curvePoolTokens[2]),
                    "CurveLP3PriceFeed"
                )
            );
        } else if (nCoins == 4) {
            _curveV1MockAddr = address(new CurveV1Mock_4Assets(curvePoolTokens, curvePoolUnderlyings));

            _priceFeed = address(
                new CurveLP4PriceFeed(
                    address(cft.addressProvider()),
                    _curveV1MockAddr,
                    cft.priceOracle().priceFeeds(curvePoolTokens[0]),
                    cft.priceOracle().priceFeeds(curvePoolTokens[1]),
                    cft.priceOracle().priceFeeds(curvePoolTokens[2]),
                    cft.priceOracle().priceFeeds(curvePoolTokens[3]),
                    "CurveLP4PriceFeed"
                )
            );
        } else {
            revert("costructor: Incorrect nCoins parameter");
        }

        lpToken = address(ICurvePool(_curveV1MockAddr).token());

        evm.startPrank(CONFIGURATOR);

        cft.priceOracle().addPriceFeed(lpToken, _priceFeed);
        creditConfigurator.addCollateralToken(lpToken, 9300);

        evm.stopPrank();

        if (nCoins == 2) {
            _adapterAddr = address(
                new CurveV1Adapter2Assets(
                    address(creditManager),
                    _curveV1MockAddr,
                    lpToken,
                    address(0)
                )
            );
        } else if (nCoins == 3) {
            _adapterAddr = address(
                new CurveV1Adapter3Assets(
                    address(creditManager),
                    _curveV1MockAddr,
                    lpToken,
                    address(0)
                )
            );
        } else if (nCoins == 4) {
            _adapterAddr = address(
                new CurveV1Adapter4Assets(
                    address(creditManager),
                    _curveV1MockAddr,
                    lpToken,
                    address(0)
                )
            );
        } else {
            revert("costructor: Incorrect nCoins parameter");
        }

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(_curveV1MockAddr, _adapterAddr);

        tokenTestSuite.mint(Tokens.cDAI, USER, DAI_ACCOUNT_AMOUNT);
        tokenTestSuite.mint(Tokens.DAI, USER, DAI_ACCOUNT_AMOUNT);

        //
        // Provide liquidity to the pool
        //
        tokenTestSuite.mint(Tokens.cDAI, _curveV1MockAddr, DAI_ACCOUNT_AMOUNT);
        tokenTestSuite.mint(Tokens.cUSDC, _curveV1MockAddr, USDC_ACCOUNT_AMOUNT);

        if (nCoins >= 3) {
            tokenTestSuite.mint(Tokens.cUSDT, _curveV1MockAddr, USDT_ACCOUNT_AMOUNT);
        }

        if (nCoins >= 4) {
            tokenTestSuite.mint(Tokens.cLINK, _curveV1MockAddr, LINK_ACCOUNT_AMOUNT);
        }

        evm.label(_adapterAddr, "ADAPTER");
        evm.label(_curveV1MockAddr, "CURVE_MOCK");
        evm.label(lpToken, "CURVE_LP_TOKEN");
    }

    function _setUpCurveStETHSuite() internal {
        _setUp(Tokens.WETH);

        address eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        address steth = tokenTestSuite.addressOf(Tokens.STETH);
        address weth = tokenTestSuite.addressOf(Tokens.WETH);

        // creditManager.addToken(tokenTestSuite.addressOf(Tokens.STETH));

        tokenTestSuite.topUpWETH{value: 1e24}();

        address[] memory coins = new address[](2);
        coins[0] = eth;
        coins[1] = steth;

        _curveV1stETHMockAddr = address(new CurveV1StETHMock(coins));

        lpToken = address(ICurvePoolStETH(_curveV1stETHMockAddr).lp_token());

        _curveV1stETHPoolGateway = address(new CurveV1StETHPoolGateway(weth, steth, _curveV1stETHMockAddr));

        address _priceFeed = address(
            new CurveLP2PriceFeed(
                address(cft.addressProvider()),
                _curveV1stETHMockAddr,
                cft.priceOracle().priceFeeds(
                    tokenTestSuite.addressOf(Tokens.WETH)
                ),
                cft.priceOracle().priceFeeds(
                    tokenTestSuite.addressOf(Tokens.STETH)
                ),
                "CurveLPETHPriceFeed"
            )
        );

        evm.startPrank(CONFIGURATOR);
        // creditConfigurator.addCollateralToken(steth, 8300);

        cft.priceOracle().addPriceFeed(lpToken, _priceFeed);
        creditConfigurator.addCollateralToken(lpToken, 8800);

        _adapterStETHAddr = address(
            new CurveV1AdapterStETH(
                address(creditManager),
                _curveV1stETHPoolGateway,
                lpToken
            )
        );

        creditConfigurator.allowContract(_curveV1stETHPoolGateway, _adapterStETHAddr);

        evm.stopPrank();

        evm.label(_adapterStETHAddr, "ADAPTER_STETH");
        evm.label(_curveV1stETHPoolGateway, "CURVE_STETH_GATEWAY");
        evm.label(_curveV1stETHMockAddr, "CURVE_STETH_POOL_MOCK");
        evm.label(lpToken, "CURVE_LP_STECRV_TOKEN");
    }

    function _setUpCurveMetapoolSuite() internal {
        _setUp(Tokens.DAI);

        poolTkns = [Tokens.cDAI, Tokens.cUSDC, Tokens.cUSDT, Tokens.cLINK];
        underlyingPoolTkns = [Tokens.DAI, Tokens.USDC, Tokens.USDT, Tokens.LINK];

        address[] memory curvePoolTokens = getPoolTokens(3);
        address[] memory curvePoolUnderlyings = getUnderlyingPoolTokens(3);

        _basePoolAddr = address(new CurveV1Mock_3Assets(curvePoolTokens, curvePoolUnderlyings));

        address _priceFeed = address(
            new CurveLP3PriceFeed(
                address(cft.addressProvider()),
                _basePoolAddr,
                cft.priceOracle().priceFeeds(curvePoolTokens[0]),
                cft.priceOracle().priceFeeds(curvePoolTokens[1]),
                cft.priceOracle().priceFeeds(curvePoolTokens[2]),
                "CurveLP3PriceFeed"
            )
        );

        address baseLpToken = address(ICurvePool(_basePoolAddr).token());

        evm.startPrank(CONFIGURATOR);

        cft.priceOracle().addPriceFeed(baseLpToken, _priceFeed);
        creditConfigurator.addCollateralToken(baseLpToken, 9300);

        evm.stopPrank();

        tokenTestSuite.mint(Tokens.cDAI, _basePoolAddr, DAI_ACCOUNT_AMOUNT);
        tokenTestSuite.mint(Tokens.cUSDC, _basePoolAddr, USDC_ACCOUNT_AMOUNT);
        tokenTestSuite.mint(Tokens.cUSDT, _basePoolAddr, USDT_ACCOUNT_AMOUNT);

        _curveV1MockAddr = address(
            new CurveV1MetapoolMock(
                tokenTestSuite.addressOf(Tokens.cLINK),
                _basePoolAddr
            )
        );

        curvePoolTokens = getPoolTokens(4);

        _priceFeed = address(
            new CurveLP4PriceFeed(
                address(cft.addressProvider()),
                _curveV1MockAddr,
                cft.priceOracle().priceFeeds(curvePoolTokens[0]),
                cft.priceOracle().priceFeeds(curvePoolTokens[1]),
                cft.priceOracle().priceFeeds(curvePoolTokens[2]),
                cft.priceOracle().priceFeeds(curvePoolTokens[3]),
                "CurveLP3PriceFeed"
            )
        );

        lpToken = address(ICurvePool(_curveV1MockAddr).token());

        evm.startPrank(CONFIGURATOR);

        cft.priceOracle().addPriceFeed(lpToken, _priceFeed);
        creditConfigurator.addCollateralToken(lpToken, 9300);

        evm.stopPrank();

        _adapterAddr = address(
            new CurveV1Adapter2Assets(
                address(creditManager),
                _curveV1MockAddr,
                lpToken,
                _basePoolAddr
            )
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(_curveV1MockAddr, _adapterAddr);

        tokenTestSuite.mint(Tokens.cLINK, _curveV1MockAddr, LINK_ACCOUNT_AMOUNT);
        CurveV1Mock(_basePoolAddr).mintLP(_curveV1MockAddr, DAI_ACCOUNT_AMOUNT);

        evm.label(_adapterAddr, "ADAPTER");
        evm.label(_curveV1MockAddr, "CURVE_MOCK");
        evm.label(lpToken, "CURVE_LP_TOKEN");
    }

    //
    // HELPERS
    //
    function getPoolTokens(uint256 nCoins) internal returns (address[] memory poolTokens) {
        require(nCoins <= poolTkns.length, "getPoolTokens: Incorrect nCoins parameter");

        poolTokens = new address[](nCoins);

        for (uint256 i = 0; i < nCoins; i++) {
            poolTokens[i] = tokenTestSuite.addressOf(poolTkns[i]);
            if (creditManager.tokenMasksMap(poolTokens[i]) == 0) {
                evm.startPrank(CONFIGURATOR);
                cft.priceOracle().addPriceFeed(
                    poolTokens[i], cft.priceOracle().priceFeeds(tokenTestSuite.addressOf(poolTkns[i]))
                );
                creditConfigurator.addCollateralToken(poolTokens[i], 9300);
                evm.stopPrank();
            }
        }
    }

    function getUnderlyingPoolTokens(uint256 nCoins) internal returns (address[] memory underlyingPoolTokens) {
        require(nCoins <= underlyingPoolTkns.length, "getUnderlyingPoolTokens: Incorrect nCoins parameter");

        underlyingPoolTokens = new address[](nCoins);

        for (uint256 i = 0; i < nCoins; i++) {
            underlyingPoolTokens[i] = tokenTestSuite.addressOf(underlyingPoolTkns[i]);
            if (creditManager.tokenMasksMap(underlyingPoolTokens[i]) == 0) {
                evm.startPrank(CONFIGURATOR);
                cft.priceOracle().addPriceFeed(
                    underlyingPoolTokens[i],
                    cft.priceOracle().priceFeeds(tokenTestSuite.addressOf(underlyingPoolTkns[i]))
                );
                creditConfigurator.addCollateralToken(underlyingPoolTokens[i], 9300);
                evm.stopPrank();
            }
        }
    }

    function _castToDynamic(uint256[2] memory arr) internal pure returns (uint256[] memory res) {
        res = new uint256[](2);
        res[0] = arr[0];
        res[1] = arr[1];
    }

    function _castToDynamic(uint256[3] memory arr) internal pure returns (uint256[] memory res) {
        res = new uint256[](3);
        res[0] = arr[0];
        res[1] = arr[1];
        res[2] = arr[2];
    }

    function _castToDynamic(uint256[4] memory arr) internal pure returns (uint256[] memory res) {
        res = new uint256[](4);
        res[0] = arr[0];
        res[1] = arr[1];
        res[2] = arr[2];
        res[3] = arr[3];
    }

    function addCRVCollateral(CurveV1Mock curveV1Mock, uint256 amount) internal {
        // provide LP token to creditAccount
        ICRVToken crv = ICRVToken(curveV1Mock.token());
        crv.set_minter(address(this));

        crv.mint(USER, amount);
        crv.set_minter(address(curveV1Mock));

        evm.startPrank(USER);
        IERC20(address(crv)).approve(address(creditManager), type(uint256).max);

        creditFacade.addCollateral(USER, address(crv), amount);

        evm.stopPrank();
    }

    //
    // CALL AND EVENT CHECKS
    //

    //
    // ADD LIQUIDITY
    //
    function expectAddLiquidityCalls(address borrower, bytes memory callData, uint256 nCoins) internal {
        address[] memory curvePoolTokens = getPoolTokens(nCoins);

        _expectAddLiquidityCalls(borrower, callData, _curveV1MockAddr, curvePoolTokens);
    }

    function expectStETHAddLiquidityCalls(address borrower, bytes memory callData) internal {
        address[] memory curvePoolTokens = new address[](2);
        curvePoolTokens[0] = tokenTestSuite.addressOf(Tokens.WETH);
        curvePoolTokens[1] = tokenTestSuite.addressOf(Tokens.STETH);

        _expectAddLiquidityCalls(borrower, callData, _curveV1stETHPoolGateway, curvePoolTokens);
    }

    function _expectAddLiquidityCalls(
        address borrower,
        bytes memory callData,
        address pool,
        address[] memory curvePoolTokens
    ) internal {
        uint256 nCoins = curvePoolTokens.length;

        evm.expectEmit(true, false, false, false);
        emit MultiCallStarted(borrower);

        for (uint256 i = 0; i < nCoins; i++) {
            evm.expectCall(
                address(creditManager),
                abi.encodeCall(ICreditManagerV2.approveCreditAccount, (pool, curvePoolTokens[i], type(uint256).max))
            );
        }

        uint256 lpTokenMask = creditManager.tokenMasksMap(lpToken);
        evm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV2.changeEnabledTokens, (lpTokenMask, 0)));

        evm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV2.executeOrder, (pool, callData)));

        evm.expectEmit(true, false, false, false);
        emit ExecuteOrder(pool);

        for (uint256 i = 0; i < nCoins; i++) {
            evm.expectCall(
                address(creditManager),
                abi.encodeCall(ICreditManagerV2.approveCreditAccount, (pool, curvePoolTokens[i], 1))
            );
        }

        evm.expectEmit(false, false, false, false);
        emit MultiCallFinished();
    }

    //
    // REMOVE LIQUIDITY
    //
    function expectRemoveLiquidityCalls(address borrower, bytes memory callData, uint256 nCoins) internal {
        address[] memory curvePoolTokens = getPoolTokens(nCoins);

        _expectRemoveLiquidityCalls(borrower, callData, _curveV1MockAddr, curvePoolTokens);
    }

    function expectStETHRemoveLiquidityCalls(address borrower, bytes memory callData) internal {
        address[] memory curvePoolTokens = new address[](2);
        curvePoolTokens[0] = tokenTestSuite.addressOf(Tokens.WETH);
        curvePoolTokens[1] = tokenTestSuite.addressOf(Tokens.STETH);

        _expectRemoveLiquidityCalls(borrower, callData, _curveV1stETHPoolGateway, curvePoolTokens);
    }

    function _expectRemoveLiquidityCalls(
        address borrower,
        bytes memory callData,
        address pool,
        address[] memory curvePoolTokens
    ) internal {
        uint256 nCoins = curvePoolTokens.length;

        evm.expectEmit(true, false, false, false);
        emit MultiCallStarted(borrower);

        uint256 tokensMask;
        for (uint256 i = 0; i < nCoins; i++) {
            tokensMask |= creditManager.tokenMasksMap(curvePoolTokens[i]);
        }
        evm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV2.changeEnabledTokens, (tokensMask, 0)));

        evm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV2.executeOrder, (pool, callData)));

        evm.expectEmit(true, false, false, false);
        emit ExecuteOrder(pool);

        evm.expectEmit(false, false, false, false);
        emit MultiCallFinished();
    }

    //
    // REMOVE LIQUIDITY IMBALANCE
    //
    function expectRemoveLiquidityImbalanceCalls(
        address borrower,
        bytes memory callData,
        uint256 nCoins,
        uint256[] memory amounts
    ) internal {
        address[] memory curvePoolTokens = getPoolTokens(nCoins);

        _expectRemoveLiquidityImbalanceCalls(borrower, callData, amounts, _curveV1MockAddr, curvePoolTokens);
    }

    function expectStETHRemoveLiquidityImbalanceCalls(
        address borrower,
        bytes memory callData,
        uint256[2] memory amounts
    ) internal {
        address[] memory curvePoolTokens = new address[](2);
        curvePoolTokens[0] = tokenTestSuite.addressOf(Tokens.WETH);
        curvePoolTokens[1] = tokenTestSuite.addressOf(Tokens.STETH);

        _expectRemoveLiquidityImbalanceCalls(
            borrower, callData, _castToDynamic(amounts), _curveV1stETHPoolGateway, curvePoolTokens
        );
    }

    function _expectRemoveLiquidityImbalanceCalls(
        address borrower,
        bytes memory callData,
        uint256[] memory amounts,
        address pool,
        address[] memory curvePoolTokens
    ) internal {
        uint256 nCoins = curvePoolTokens.length;

        evm.expectEmit(true, false, false, false);
        emit MultiCallStarted(borrower);

        uint256 tokensMask;
        for (uint256 i = 0; i < nCoins; i++) {
            if (amounts[i] > 0) {
                tokensMask |= creditManager.tokenMasksMap(curvePoolTokens[i]);
            }
        }
        evm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV2.changeEnabledTokens, (tokensMask, 0)));

        evm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV2.executeOrder, (pool, callData)));

        evm.expectEmit(true, false, false, false);
        emit ExecuteOrder(pool);

        evm.expectEmit(false, false, false, false);
        emit MultiCallFinished();
    }

    function expectRemoveLiquidityImbalanceCalls(
        address borrower,
        bytes memory callData,
        uint256 nCoins,
        uint256[2] memory amounts
    ) internal {
        uint256[] memory amts = _castToDynamic(amounts);
        expectRemoveLiquidityImbalanceCalls(borrower, callData, nCoins, amts);
    }

    function expectRemoveLiquidityImbalanceCalls(
        address borrower,
        bytes memory callData,
        uint256 nCoins,
        uint256[3] memory amounts
    ) internal {
        uint256[] memory amts = _castToDynamic(amounts);
        expectRemoveLiquidityImbalanceCalls(borrower, callData, nCoins, amts);
    }

    function expectRemoveLiquidityImbalanceCalls(
        address borrower,
        bytes memory callData,
        uint256 nCoins,
        uint256[4] memory amounts
    ) internal {
        uint256[] memory amts = _castToDynamic(amounts);
        expectRemoveLiquidityImbalanceCalls(borrower, callData, nCoins, amts);
    }
}
