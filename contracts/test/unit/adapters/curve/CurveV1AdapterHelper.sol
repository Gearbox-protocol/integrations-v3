// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CurveV1Adapter2Assets} from "../../../../adapters/curve/CurveV1_2.sol";
import {CurveV1Adapter3Assets} from "../../../../adapters/curve/CurveV1_3.sol";
import {CurveV1Adapter4Assets} from "../../../../adapters/curve/CurveV1_4.sol";
import {CurveV1StETHPoolGateway} from "../../../../helpers/curve/CurveV1_stETHGateway.sol";
import {CurveV1AdapterStETH} from "../../../../adapters/curve/CurveV1_stETH.sol";
import {ICurveV1Adapter, ICurveV1AdapterExceptions} from "../../../../interfaces/curve/ICurveV1Adapter.sol";
import {ICurvePoolStETH} from "../../../../integrations/curve/ICurvePoolStETH.sol";
import {ICurvePool} from "../../../../integrations/curve/ICurvePool.sol";
import {ICRVToken} from "../../../../integrations/curve/ICRVToken.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {CurveV1StETHMock} from "../../../mocks/integrations/CurveV1StETHMock.sol";

import {CurveV1Mock} from "../../../mocks/integrations/CurveV1Mock.sol";
import {CurveV1MetapoolMock} from "../../../mocks/integrations/CurveV1MetapoolMock.sol";
import {CurveV1Mock_2Assets} from "../../../mocks/integrations/CurveV1Mock_2Assets.sol";
import {CurveV1Mock_3Assets} from "../../../mocks/integrations/CurveV1Mock_3Assets.sol";
import {CurveV1Mock_4Assets} from "../../../mocks/integrations/CurveV1Mock_4Assets.sol";

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";

import {PriceFeedParams} from "@gearbox-protocol/oracles-v3/contracts/oracles/PriceFeedParams.sol";
import {CurveStableLPPriceFeed} from "@gearbox-protocol/oracles-v3/contracts/oracles/curve/CurveStableLPPriceFeed.sol";
import {CurveCryptoLPPriceFeed} from "@gearbox-protocol/oracles-v3/contracts/oracles/curve/CurveCryptoLPPriceFeed.sol";

// TEST
import "../../../lib/constants.sol";

import {AdapterTestHelper} from "../AdapterTestHelper.sol";

uint256 constant DAI_TO_LP = DAI_ACCOUNT_AMOUNT / 4;
uint256 constant USDC_TO_LP = USDC_ACCOUNT_AMOUNT / 3;
uint256 constant USDT_TO_LP = USDT_ACCOUNT_AMOUNT / 5;
uint256 constant LINK_TO_LP = LINK_ACCOUNT_AMOUNT / 5;

/// @title CurveV1AdapterHelper
/// @notice Designed for unit test purposes only
contract CurveV1AdapterHelper is Test, AdapterTestHelper, ICurveV1AdapterExceptions {
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
                new CurveStableLPPriceFeed(
                address(addressProvider),
                _curveV1MockAddr,
                  _curveV1MockAddr,
                [ PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[0]), stalenessPeriod: 48 hours}),
                 PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[1]), stalenessPeriod: 48 hours}),
                  PriceFeedParams({ priceFeed: address(0), stalenessPeriod: 0}),
                  PriceFeedParams({ priceFeed: address(0), stalenessPeriod: 0})]

                )
            );
        } else if (nCoins == 3) {
            _curveV1MockAddr = address(new CurveV1Mock_3Assets(curvePoolTokens, curvePoolUnderlyings));

            _priceFeed = address(
                new CurveStableLPPriceFeed(
                address(addressProvider),
                _curveV1MockAddr,
                  _curveV1MockAddr,
                [ PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[0]), stalenessPeriod: 48 hours}),
                 PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[1]), stalenessPeriod: 48 hours}),
                PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[2]), stalenessPeriod: 48 hours}),
                  PriceFeedParams({ priceFeed: address(0), stalenessPeriod: 0})]

                )
            );
        } else if (nCoins == 4) {
            _curveV1MockAddr = address(new CurveV1Mock_4Assets(curvePoolTokens, curvePoolUnderlyings));

            _priceFeed = address(
                new CurveStableLPPriceFeed(
                address(addressProvider),
                _curveV1MockAddr,
                       _curveV1MockAddr,
                [ PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[0]), stalenessPeriod: 48 hours}),
                 PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[1]), stalenessPeriod: 48 hours}),
                PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[2]), stalenessPeriod: 48 hours}),
                PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[3]), stalenessPeriod: 48 hours})]

                )
            );
        } else {
            revert("costructor: Incorrect nCoins parameter");
        }

        lpToken = address(ICurvePool(_curveV1MockAddr).token());

        vm.startPrank(CONFIGURATOR);

        priceOracle.setPriceFeed(lpToken, _priceFeed, 0);
        creditConfigurator.addCollateralToken(lpToken, 9300);

        vm.stopPrank();

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

        vm.prank(CONFIGURATOR);
        creditConfigurator.allowAdapter(_adapterAddr);

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

        vm.label(_adapterAddr, "ADAPTER");
        vm.label(_curveV1MockAddr, "CURVE_MOCK");
        vm.label(lpToken, "CURVE_LP_TOKEN");
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
            new CurveStableLPPriceFeed(
                address(addressProvider),
                _curveV1stETHMockAddr,
                  _curveV1stETHMockAddr,

                  [ PriceFeedParams({ priceFeed: priceOracle.priceFeeds(tokenTestSuite.addressOf(Tokens.WETH)), stalenessPeriod: 48 hours}),
                 PriceFeedParams({ priceFeed: priceOracle.priceFeeds(tokenTestSuite.addressOf(Tokens.STETH)), stalenessPeriod: 48 hours}),
                  PriceFeedParams({ priceFeed: address(0), stalenessPeriod: 0}),
                  PriceFeedParams({ priceFeed: address(0), stalenessPeriod: 0})]
             

            )
        );

        vm.startPrank(CONFIGURATOR);
        // creditConfigurator.addCollateralToken(steth, 8300);

        priceOracle.setPriceFeed(lpToken, _priceFeed, 0);
        creditConfigurator.addCollateralToken(lpToken, 8800);

        _adapterStETHAddr = address(
            new CurveV1AdapterStETH(
                address(creditManager),
                _curveV1stETHPoolGateway,
                lpToken
            )
        );

        creditConfigurator.allowAdapter(_adapterStETHAddr);

        vm.stopPrank();

        vm.label(_adapterStETHAddr, "ADAPTER_STETH");
        vm.label(_curveV1stETHPoolGateway, "CURVE_STETH_GATEWAY");
        vm.label(_curveV1stETHMockAddr, "CURVE_STETH_POOL_MOCK");
        vm.label(lpToken, "CURVE_LP_STECRV_TOKEN");
    }

    function _setUpCurveMetapoolSuite() internal {
        _setUp(Tokens.DAI);

        poolTkns = [Tokens.cDAI, Tokens.cUSDC, Tokens.cUSDT, Tokens.cLINK];
        underlyingPoolTkns = [Tokens.DAI, Tokens.USDC, Tokens.USDT, Tokens.LINK];

        address[] memory curvePoolTokens = getPoolTokens(3);
        address[] memory curvePoolUnderlyings = getUnderlyingPoolTokens(3);

        _basePoolAddr = address(new CurveV1Mock_3Assets(curvePoolTokens, curvePoolUnderlyings));

        address _priceFeed = address(
            new CurveStableLPPriceFeed(
                address(addressProvider),
                _basePoolAddr,
                _basePoolAddr,
                [PriceFeedParams({ priceFeed:  priceOracle.priceFeeds(curvePoolTokens[0]),
                stalenessPeriod: 48 hours}),
                 PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[1]), stalenessPeriod: 48 hours}),
                 PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[2]), stalenessPeriod: 48 hours}),
                 PriceFeedParams({ priceFeed: address(0), stalenessPeriod: 0})]

            )
        );

        address baseLpToken = address(ICurvePool(_basePoolAddr).token());

        vm.startPrank(CONFIGURATOR);

        priceOracle.setPriceFeed(baseLpToken, _priceFeed, 0);
        creditConfigurator.addCollateralToken(baseLpToken, 9300);

        vm.stopPrank();

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
            new CurveStableLPPriceFeed(
                address(addressProvider),
                _curveV1MockAddr,
                  _curveV1MockAddr,
               [PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[0]), stalenessPeriod: 48 hours }),
                PriceFeedParams({ priceFeed:priceOracle.priceFeeds(curvePoolTokens[1]),stalenessPeriod: 48 hours }),
                PriceFeedParams({ priceFeed:priceOracle.priceFeeds(curvePoolTokens[2]),stalenessPeriod: 48 hours }),
                PriceFeedParams({ priceFeed:priceOracle.priceFeeds(curvePoolTokens[3]),stalenessPeriod: 48 hours })]

            )
        );

        lpToken = address(ICurvePool(_curveV1MockAddr).token());

        vm.startPrank(CONFIGURATOR);

        priceOracle.setPriceFeed(lpToken, _priceFeed, 0);
        creditConfigurator.addCollateralToken(lpToken, 9300);

        vm.stopPrank();

        _adapterAddr = address(
            new CurveV1Adapter2Assets(
                address(creditManager),
                _curveV1MockAddr,
                lpToken,
                _basePoolAddr
            )
        );

        vm.prank(CONFIGURATOR);
        creditConfigurator.allowAdapter(_adapterAddr);

        tokenTestSuite.mint(Tokens.cLINK, _curveV1MockAddr, LINK_ACCOUNT_AMOUNT);
        CurveV1Mock(_basePoolAddr).mintLP(_curveV1MockAddr, DAI_ACCOUNT_AMOUNT);

        vm.label(_adapterAddr, "ADAPTER");
        vm.label(_curveV1MockAddr, "CURVE_MOCK");
        vm.label(lpToken, "CURVE_LP_TOKEN");
    }

    function _setUpCurveCryptoSuite() internal {
        _setUp(Tokens.DAI);

        poolTkns = [Tokens.cDAI, Tokens.cUSDC, Tokens.cUSDT, Tokens.cLINK];
        underlyingPoolTkns = [Tokens.DAI, Tokens.USDC, Tokens.USDT, Tokens.LINK];

        address[] memory curvePoolTokens = getPoolTokens(3);
        address[] memory curvePoolUnderlyings = getUnderlyingPoolTokens(3);

        _basePoolAddr = address(new CurveV1Mock_3Assets(curvePoolTokens, curvePoolUnderlyings));

        address _basePriceFeed = address(
            new CurveStableLPPriceFeed(
                address(addressProvider),
                _basePoolAddr,
                 _basePoolAddr,
                [PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[0]), stalenessPeriod: 48 hours}),
                 PriceFeedParams({ priceFeed: priceOracle.priceFeeds(curvePoolTokens[1]),stalenessPeriod: 48 hours}),
                PriceFeedParams({priceFeed:  priceOracle.priceFeeds(curvePoolTokens[2]),stalenessPeriod: 48 hours}),
                PriceFeedParams({priceFeed: address(0),stalenessPeriod:0})]

            )
        );

        address baseLpToken = address(ICurvePool(_basePoolAddr).token());

        vm.startPrank(CONFIGURATOR);

        priceOracle.setPriceFeed(baseLpToken, _basePriceFeed, 0);
        creditConfigurator.addCollateralToken(baseLpToken, 9300);

        vm.stopPrank();

        tokenTestSuite.mint(Tokens.cDAI, _basePoolAddr, LINK_ACCOUNT_AMOUNT * 100);
        tokenTestSuite.mint(Tokens.cUSDC, _basePoolAddr, LINK_ACCOUNT_AMOUNT * 100);
        tokenTestSuite.mint(Tokens.cUSDT, _basePoolAddr, LINK_ACCOUNT_AMOUNT * 100);

        _curveV1MockAddr = address(
            new CurveV1MetapoolMock(
                tokenTestSuite.addressOf(Tokens.cLINK),
                _basePoolAddr
            )
        );

        CurveV1MetapoolMock(_curveV1MockAddr).setIsCryptoPool(true);

        curvePoolTokens = getPoolTokens(4);

        address _priceFeed = address(
            new CurveCryptoLPPriceFeed(
                address(addressProvider),
                _curveV1MockAddr,
                     _curveV1MockAddr,
                [PriceFeedParams({priceFeed: priceOracle.priceFeeds(curvePoolTokens[3]), stalenessPeriod:  48 hours}),
               PriceFeedParams({priceFeed: _basePriceFeed,stalenessPeriod: 0}),
               PriceFeedParams({priceFeed: address(0), stalenessPeriod: 0})]

            )
        );

        lpToken = address(ICurvePool(_curveV1MockAddr).token());

        vm.startPrank(CONFIGURATOR);

        priceOracle.setPriceFeed(lpToken, _priceFeed, 0);
        creditConfigurator.addCollateralToken(lpToken, 9300);

        vm.stopPrank();

        _adapterAddr = address(
            new CurveV1Adapter2Assets(
                address(creditManager),
                _curveV1MockAddr,
                lpToken,
                _basePoolAddr
            )
        );

        vm.prank(CONFIGURATOR);
        creditConfigurator.allowAdapter(_adapterAddr);

        tokenTestSuite.mint(Tokens.cLINK, _curveV1MockAddr, LINK_ACCOUNT_AMOUNT);
        CurveV1Mock(_basePoolAddr).mintLP(_curveV1MockAddr, DAI_ACCOUNT_AMOUNT * 100);

        vm.label(_adapterAddr, "ADAPTER");
        vm.label(_curveV1MockAddr, "CURVE_MOCK");
        vm.label(lpToken, "CURVE_LP_TOKEN");
    }

    //
    // HELPERS
    //
    function getPoolTokens(uint256 nCoins) internal returns (address[] memory poolTokens) {
        require(nCoins <= poolTkns.length, "getPoolTokens: Incorrect nCoins parameter");

        poolTokens = new address[](nCoins);

        for (uint256 i = 0; i < nCoins; i++) {
            poolTokens[i] = tokenTestSuite.addressOf(poolTkns[i]);
            if (creditManager.getTokenMaskOrRevert(poolTokens[i]) == 0) {
                vm.startPrank(CONFIGURATOR);
                priceOracle.setPriceFeed(
                    poolTokens[i], priceOracle.priceFeeds(tokenTestSuite.addressOf(poolTkns[i])), 0
                );
                creditConfigurator.addCollateralToken(poolTokens[i], 9300);
                vm.stopPrank();
            }
        }
    }

    function getUnderlyingPoolTokens(uint256 nCoins) internal returns (address[] memory underlyingPoolTokens) {
        require(nCoins <= underlyingPoolTkns.length, "getUnderlyingPoolTokens: Incorrect nCoins parameter");

        underlyingPoolTokens = new address[](nCoins);

        for (uint256 i = 0; i < nCoins; i++) {
            underlyingPoolTokens[i] = tokenTestSuite.addressOf(underlyingPoolTkns[i]);
            if (creditManager.getTokenMaskOrRevert(underlyingPoolTokens[i]) == 0) {
                vm.startPrank(CONFIGURATOR);
                priceOracle.setPriceFeed(
                    underlyingPoolTokens[i],
                    priceOracle.priceFeeds(tokenTestSuite.addressOf(underlyingPoolTkns[i])),
                    48 hours
                );
                creditConfigurator.addCollateralToken(underlyingPoolTokens[i], 9300);
                vm.stopPrank();
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

        vm.startPrank(USER);
        IERC20(address(crv)).approve(address(creditManager), type(uint256).max);

        // creditFacade.addCollateral(USER, address(crv), amount);

        vm.stopPrank();
    }

    //
    // CALL AND EVENT CHECKS
    //

    //
    // ADD LIQUIDITY
    //
    function expectAddLiquidityCalls(address creditAccount, address borrower, bytes memory callData, uint256 nCoins)
        internal
    {
        address[] memory curvePoolTokens = getPoolTokens(nCoins);

        _expectAddLiquidityCalls(creditAccount, borrower, callData, _curveV1MockAddr, curvePoolTokens);
    }

    function expectStETHAddLiquidityCalls(address creditAccount, address borrower, bytes memory callData) internal {
        address[] memory curvePoolTokens = new address[](2);
        curvePoolTokens[0] = tokenTestSuite.addressOf(Tokens.WETH);
        curvePoolTokens[1] = tokenTestSuite.addressOf(Tokens.STETH);

        _expectAddLiquidityCalls(creditAccount, borrower, callData, _curveV1stETHPoolGateway, curvePoolTokens);
    }

    function _expectAddLiquidityCalls(
        address creditAccount,
        address borrower,
        bytes memory callData,
        address pool,
        address[] memory curvePoolTokens
    ) internal {
        uint256 nCoins = curvePoolTokens.length;

        vm.expectEmit(true, false, false, false);
        emit StartMultiCall(creditAccount, borrower);

        for (uint256 i = 0; i < nCoins; i++) {
            vm.expectCall(
                address(creditManager),
                abi.encodeCall(ICreditManagerV3.approveCreditAccount, (curvePoolTokens[i], type(uint256).max))
            );
        }

        uint256 lpTokenMask = creditManager.getTokenMaskOrRevert(lpToken);

        vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.execute, (callData)));

        vm.expectEmit(true, false, false, false);
        emit Execute(creditAccount, pool);

        for (uint256 i = 0; i < nCoins; i++) {
            vm.expectCall(
                address(creditManager), abi.encodeCall(ICreditManagerV3.approveCreditAccount, (curvePoolTokens[i], 1))
            );
        }

        vm.expectEmit(false, false, false, false);
        emit FinishMultiCall();
    }

    //
    // REMOVE LIQUIDITY
    //
    function expectRemoveLiquidityCalls(address creditAccount, address borrower, bytes memory callData, uint256 nCoins)
        internal
    {
        address[] memory curvePoolTokens = getPoolTokens(nCoins);

        _expectRemoveLiquidityCalls(creditAccount, borrower, callData, _curveV1MockAddr, curvePoolTokens);
    }

    function expectStETHRemoveLiquidityCalls(address creditAccount, address borrower, bytes memory callData) internal {
        address[] memory curvePoolTokens = new address[](2);
        curvePoolTokens[0] = tokenTestSuite.addressOf(Tokens.WETH);
        curvePoolTokens[1] = tokenTestSuite.addressOf(Tokens.STETH);

        _expectRemoveLiquidityCalls(creditAccount, borrower, callData, _curveV1stETHPoolGateway, curvePoolTokens);
    }

    function _expectRemoveLiquidityCalls(
        address creditAccount,
        address borrower,
        bytes memory callData,
        address pool,
        address[] memory curvePoolTokens
    ) internal {
        uint256 nCoins = curvePoolTokens.length;

        vm.expectEmit(true, false, false, false);
        emit StartMultiCall(creditAccount, borrower);

        uint256 tokensMask;
        for (uint256 i = 0; i < nCoins; i++) {
            tokensMask |= creditManager.getTokenMaskOrRevert(curvePoolTokens[i]);
        }

        vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.execute, (callData)));

        vm.expectEmit(true, false, false, false);
        emit Execute(creditAccount, pool);

        vm.expectEmit(false, false, false, false);
        emit FinishMultiCall();
    }

    //
    // REMOVE LIQUIDITY IMBALANCE
    //
    function expectRemoveLiquidityImbalanceCalls(
        address creditAccount,
        address borrower,
        bytes memory callData,
        uint256 nCoins,
        uint256[] memory amounts
    ) internal {
        address[] memory curvePoolTokens = getPoolTokens(nCoins);

        _expectRemoveLiquidityImbalanceCalls(
            creditAccount, borrower, callData, amounts, _curveV1MockAddr, curvePoolTokens
        );
    }

    function expectStETHRemoveLiquidityImbalanceCalls(
        address creditAccount,
        address borrower,
        bytes memory callData,
        uint256[2] memory amounts
    ) internal {
        address[] memory curvePoolTokens = new address[](2);
        curvePoolTokens[0] = tokenTestSuite.addressOf(Tokens.WETH);
        curvePoolTokens[1] = tokenTestSuite.addressOf(Tokens.STETH);

        _expectRemoveLiquidityImbalanceCalls(
            creditAccount, borrower, callData, _castToDynamic(amounts), _curveV1stETHPoolGateway, curvePoolTokens
        );
    }

    function _expectRemoveLiquidityImbalanceCalls(
        address creditAccount,
        address borrower,
        bytes memory callData,
        uint256[] memory amounts,
        address pool,
        address[] memory curvePoolTokens
    ) internal {
        uint256 nCoins = curvePoolTokens.length;

        vm.expectEmit(true, false, false, false);
        emit StartMultiCall(creditAccount, borrower);

        uint256 tokensMask;
        for (uint256 i = 0; i < nCoins; i++) {
            if (amounts[i] > 0) {
                tokensMask |= creditManager.getTokenMaskOrRevert(curvePoolTokens[i]);
            }
        }

        vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.execute, (callData)));

        vm.expectEmit(true, false, false, false);
        emit Execute(creditAccount, pool);

        vm.expectEmit(false, false, false, false);
        emit FinishMultiCall();
    }

    function expectRemoveLiquidityImbalanceCalls(
        address creditAccount,
        address borrower,
        bytes memory callData,
        uint256 nCoins,
        uint256[2] memory amounts
    ) internal {
        uint256[] memory amts = _castToDynamic(amounts);
        expectRemoveLiquidityImbalanceCalls(creditAccount, borrower, callData, nCoins, amts);
    }

    function expectRemoveLiquidityImbalanceCalls(
        address creditAccount,
        address borrower,
        bytes memory callData,
        uint256 nCoins,
        uint256[3] memory amounts
    ) internal {
        uint256[] memory amts = _castToDynamic(amounts);
        expectRemoveLiquidityImbalanceCalls(creditAccount, borrower, callData, nCoins, amts);
    }

    function expectRemoveLiquidityImbalanceCalls(
        address creditAccount,
        address borrower,
        bytes memory callData,
        uint256 nCoins,
        uint256[4] memory amounts
    ) internal {
        uint256[] memory amts = _castToDynamic(amounts);
        expectRemoveLiquidityImbalanceCalls(creditAccount, borrower, callData, nCoins, amts);
    }
}
