// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { CreditManager } from "@gearbox-protocol/core-v2/contracts/credit/CreditManager.sol";

import { IBooster } from "../../../integrations/convex/IBooster.sol";
import { IBaseRewardPool } from "../../../integrations/convex/IBaseRewardPool.sol";

import { IPriceOracleV2Ext } from "@gearbox-protocol/core-v2/contracts/interfaces/IPriceOracle.sol";

import { IConvexV1BaseRewardPoolAdapterErrors } from "../../../interfaces/convex/IConvexV1BaseRewardPoolAdapter.sol";

import { ConvexV1BaseRewardPoolAdapter } from "../../../adapters/convex/ConvexV1_BaseRewardPool.sol";
import { ConvexV1BoosterAdapter } from "../../../adapters/convex/ConvexV1_Booster.sol";
import { ConvexV1ClaimZapAdapter } from "../../../adapters/convex/ConvexV1_ClaimZap.sol";
import { ConvexStakedPositionToken } from "../../../adapters/convex/ConvexV1_StakedPositionToken.sol";

import { BoosterMock } from "../../mocks/integrations/ConvexBoosterMock.sol";
import { BaseRewardPoolMock } from "../../mocks/integrations/ConvexBaseRewardPoolMock.sol";
import { ExtraRewardPoolMock } from "../../mocks/integrations/ConvexExtraRewardPoolMock.sol";
import { ClaimZapMock } from "../../mocks/integrations/ConvexClaimZapMock.sol";

import { PriceFeedMock } from "@gearbox-protocol/core-v2/contracts/test/mocks/oracles/PriceFeedMock.sol";

import { WAD, RAY } from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";
import { ERC20Mock } from "@gearbox-protocol/core-v2/contracts/test/mocks/token/ERC20Mock.sol";

import { AdapterTestHelper } from "../AdapterTestHelper.sol";

import { USER, CONFIGURATOR, DAI_MIN_BORROWED_AMOUNT, DAI_MAX_BORROWED_AMOUNT } from "../../lib/constants.sol";

uint256 constant CURVE_LP_AMOUNT = 10000 * RAY;
uint256 constant DAI_ACCOUNT_AMOUNT = 10000 * WAD;
uint256 constant REWARD_AMOUNT = RAY;
uint256 constant REWARD_AMOUNT1 = RAY * 33;
uint256 constant REWARD_AMOUNT2 = RAY * 4;

/// @title ConvexAdapterHelper
/// @notice Designed for unit test purposes only
contract ConvexAdapterHelper is
    AdapterTestHelper,
    IConvexV1BaseRewardPoolAdapterErrors
{
    PriceFeedMock public feed;
    IPriceOracleV2Ext public priceOracle;

    address public crv;
    address public cvx;

    address public curveLPToken;
    address public convexLPToken;
    address public phantomToken;
    address public extraRewardToken1;
    address public extraRewardToken2;

    BoosterMock public boosterMock;
    BaseRewardPoolMock public basePoolMock;
    ExtraRewardPoolMock public extraPoolMock1;
    ExtraRewardPoolMock public extraPoolMock2;
    ClaimZapMock public claimZapMock;

    ConvexV1BaseRewardPoolAdapter public basePoolAdapter;
    ConvexV1BoosterAdapter public boosterAdapter;
    ConvexV1ClaimZapAdapter public claimZapAdapter;

    struct PoolInfo {
        address lptoken;
        address token;
        address gauge;
        address crvRewards;
        address stash;
        bool shutdown;
    }

    function _setupConvexSuite(uint256 extraRewardsCount) internal {
        _setUp();

        feed = new PriceFeedMock(1000, 8);
        priceOracle = cft.priceOracle();

        curveLPToken = address(new ERC20Mock("Curve LP Token", "CRVLP", 18));
        _addToken(curveLPToken);

        crv = address(new ERC20Mock("Curve", "CRV", 18));
        _addToken(crv);

        cvx = address(new ERC20Mock("Convex", "CVX", 18));
        _addToken(cvx);

        if (extraRewardsCount >= 1) {
            extraRewardToken1 = address(
                new ERC20Mock("Extra Reward 1", "EXTR1", 18)
            );
            _addToken(extraRewardToken1);
        }

        if (extraRewardsCount >= 2) {
            extraRewardToken2 = address(
                new ERC20Mock("Extra Reward 2", "EXTR2", 18)
            );
            _addToken(extraRewardToken2);
        }

        boosterMock = new BoosterMock(crv, cvx);
        boosterMock.addPool(curveLPToken);

        IBooster.PoolInfo memory pool = IBooster(address(boosterMock)).poolInfo(
            0
        );

        convexLPToken = pool.token;
        _addToken(convexLPToken);

        basePoolMock = BaseRewardPoolMock(pool.crvRewards);

        if (extraRewardsCount >= 1) {
            extraPoolMock1 = new ExtraRewardPoolMock(
                address(basePoolMock),
                extraRewardToken1,
                address(boosterMock)
            );

            basePoolMock.addExtraReward(address(extraPoolMock1));
        }

        if (extraRewardsCount >= 2) {
            extraPoolMock2 = new ExtraRewardPoolMock(
                address(basePoolMock),
                extraRewardToken2,
                address(boosterMock)
            );

            basePoolMock.addExtraReward(address(extraPoolMock2));
        }

        claimZapMock = new ClaimZapMock(crv, cvx);

        phantomToken = address(
            new ConvexStakedPositionToken(address(basePoolMock), convexLPToken)
        );

        basePoolAdapter = new ConvexV1BaseRewardPoolAdapter(
            address(creditManager),
            address(basePoolMock),
            phantomToken
        );

        _addToken(phantomToken);

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(
            address(basePoolMock),
            address(basePoolAdapter)
        );

        boosterAdapter = new ConvexV1BoosterAdapter(
            address(creditManager),
            address(boosterMock)
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(
            address(boosterMock),
            address(boosterAdapter)
        );

        claimZapAdapter = new ConvexV1ClaimZapAdapter(
            address(creditManager),
            address(claimZapMock)
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(
            address(claimZapMock),
            address(claimZapAdapter)
        );

        evm.prank(CONFIGURATOR);
        boosterAdapter.updateStakedPhantomTokensMap();
    }

    function _checkPoolAdapterConstructorRevert(uint256 forgottenToken)
        internal
    {
        address forgottenTokenAddr;

        address curveLPToken_c = address(
            new ERC20Mock("Curve LP Token", "CRVLP", 18)
        );

        if (forgottenToken == 2) {
            forgottenTokenAddr = curveLPToken_c;
        } else {
            _addToken(curveLPToken_c);
        }

        address crv_c = address(new ERC20Mock("Curve", "CRV", 18));

        if (forgottenToken == 0) {
            forgottenTokenAddr = crv_c;
        } else {
            _addToken(crv_c);
        }

        address cvx_c = address(new ERC20Mock("Convex", "CVX", 18));

        if (forgottenToken == 1) {
            forgottenTokenAddr = cvx_c;
        } else {
            _addToken(cvx_c);
        }

        address extraRewardToken1_c = address(
            new ERC20Mock("Extra Reward 1", "EXTR1", 18)
        );

        if (forgottenToken == 3) {
            forgottenTokenAddr = extraRewardToken1_c;
        } else {
            _addToken(extraRewardToken1_c);
        }

        address extraRewardToken2_c = address(
            new ERC20Mock("Extra Reward 2", "EXTR2", 18)
        );

        if (forgottenToken == 4) {
            forgottenTokenAddr = extraRewardToken2_c;
        } else {
            _addToken(extraRewardToken2_c);
        }

        BoosterMock boosterMock_c = new BoosterMock(crv_c, cvx_c);
        boosterMock_c.addPool(curveLPToken_c);

        IBooster.PoolInfo memory pool = IBooster(address(boosterMock_c))
            .poolInfo(0);

        address convexLPToken_c = pool.token;
        _addToken(convexLPToken_c);

        BaseRewardPoolMock basePoolMock_c = BaseRewardPoolMock(pool.crvRewards);

        ExtraRewardPoolMock extraPoolMock1_c = new ExtraRewardPoolMock(
            address(basePoolMock_c),
            extraRewardToken1_c,
            address(boosterMock_c)
        );

        basePoolMock_c.addExtraReward(address(extraPoolMock1_c));

        ExtraRewardPoolMock extraPoolMock2_c = new ExtraRewardPoolMock(
            address(basePoolMock_c),
            extraRewardToken2_c,
            address(boosterMock_c)
        );

        basePoolMock_c.addExtraReward(address(extraPoolMock2_c));

        evm.expectRevert(
            abi.encodeWithSelector(
                TokenIsNotAddedToCreditManagerException.selector,
                forgottenTokenAddr
            )
        );

        new ConvexV1BaseRewardPoolAdapter(
            address(creditManager),
            address(basePoolMock_c),
            phantomToken
        );
    }

    function _addToken(address token) internal {
        evm.startPrank(CONFIGURATOR);
        priceOracle.addPriceFeed(token, address(feed));
        creditConfigurator.addCollateralToken(token, 9300);
        evm.stopPrank();
    }

    function expectDepositStackCalls(
        address borrower,
        uint256 amount,
        bool stake,
        bool depositAll,
        bool isMultiCall
    ) internal {
        bytes memory callData = depositAll
            ? abi.encodeWithSelector(IBooster.depositAll.selector, 0, stake)
            : abi.encodeWithSelector(
                IBooster.deposit.selector,
                0,
                amount,
                stake
            );

        if (isMultiCall) {
            expectMulticallStackCalls(
                address(boosterAdapter),
                address(boosterMock),
                borrower,
                callData,
                curveLPToken,
                stake ? phantomToken : convexLPToken,
                true
            );
        } else {
            expectFastCheckStackCalls(
                address(boosterAdapter),
                address(boosterMock),
                borrower,
                callData,
                curveLPToken,
                stake ? phantomToken : convexLPToken,
                true
            );
        }
    }

    function expectWithdrawStackCalls(
        address borrower,
        uint256 amount,
        bool withdrawAll,
        bool isMultiCall
    ) internal {
        bytes memory callData = withdrawAll
            ? abi.encodeWithSelector(IBooster.withdrawAll.selector, 0)
            : abi.encodeWithSelector(IBooster.withdraw.selector, 0, amount);

        if (isMultiCall) {
            expectMulticallStackCalls(
                address(boosterAdapter),
                address(boosterMock),
                borrower,
                callData,
                convexLPToken,
                curveLPToken,
                true,
                false
            );
        } else {
            expectFastCheckStackCalls(
                address(boosterAdapter),
                address(boosterMock),
                borrower,
                callData,
                convexLPToken,
                curveLPToken,
                true,
                false
            );
        }
    }

    function expectStakeStackCalls(
        address borrower,
        uint256 amount,
        bool stakeAll,
        bool isMultiCall
    ) internal {
        bytes memory callData = stakeAll
            ? abi.encodeWithSelector(IBaseRewardPool.stakeAll.selector)
            : abi.encodeWithSelector(IBaseRewardPool.stake.selector, amount);

        if (isMultiCall) {
            expectMulticallStackCalls(
                address(basePoolAdapter),
                address(basePoolMock),
                borrower,
                callData,
                convexLPToken,
                phantomToken,
                true
            );
        } else {
            expectFastCheckStackCalls(
                address(basePoolAdapter),
                address(basePoolMock),
                borrower,
                callData,
                convexLPToken,
                phantomToken,
                true
            );
        }
    }

    function expectPoolWithdrawStackCalls(
        address borrower,
        uint256 amount,
        bool withdrawAll,
        bool unwrap,
        bool isMultiCall,
        uint256 numExtras
    ) internal {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            borrower
        );

        bytes memory callData;

        if (unwrap) {
            callData = withdrawAll
                ? abi.encodeWithSelector(
                    IBaseRewardPool.withdrawAllAndUnwrap.selector,
                    true
                )
                : abi.encodeWithSelector(
                    IBaseRewardPool.withdrawAndUnwrap.selector,
                    amount,
                    true
                );
        } else {
            callData = withdrawAll
                ? abi.encodeWithSelector(
                    IBaseRewardPool.withdrawAll.selector,
                    true
                )
                : abi.encodeWithSelector(
                    IBaseRewardPool.withdraw.selector,
                    amount,
                    true
                );
        }

        if (isMultiCall) {
            expectMulticallStackCalls(
                address(basePoolAdapter),
                address(basePoolMock),
                borrower,
                callData,
                phantomToken,
                unwrap ? curveLPToken : convexLPToken,
                true,
                false
            );
        } else {
            expectFastCheckStackCalls(
                address(basePoolAdapter),
                address(basePoolMock),
                borrower,
                callData,
                phantomToken,
                unwrap ? curveLPToken : convexLPToken,
                true,
                false
            );
        }
        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                CreditManager.checkAndEnableToken.selector,
                creditAccount,
                crv
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                CreditManager.checkAndEnableToken.selector,
                creditAccount,
                cvx
            )
        );

        if (numExtras >= 1) {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    CreditManager.checkAndEnableToken.selector,
                    creditAccount,
                    extraRewardToken1
                )
            );
        }
        if (numExtras == 2) {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    CreditManager.checkAndEnableToken.selector,
                    creditAccount,
                    extraRewardToken2
                )
            );
        }
    }

    function expectClaimZapStackCalls(
        address borrower,
        bytes memory callData,
        address[] memory enabledTokens,
        bool isMultiCall
    ) internal {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            borrower
        );

        if (isMultiCall) {
            evm.expectEmit(true, false, false, false);
            emit MultiCallStarted(borrower);

            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    CreditManager.executeOrder.selector,
                    address(creditFacade),
                    address(claimZapMock),
                    callData
                )
            );
        } else {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    CreditManager.executeOrder.selector,
                    borrower,
                    address(claimZapMock),
                    callData
                )
            );
        }

        for (uint256 i = 0; i < enabledTokens.length; i++) {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    CreditManager.checkAndEnableToken.selector,
                    creditAccount,
                    enabledTokens[i]
                )
            );
        }

        if (isMultiCall) {
            evm.expectEmit(false, false, false, false);
            emit MultiCallFinished();
        } else {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    CreditManager.checkAndOptimizeEnabledTokens.selector,
                    creditAccount
                )
            );
        }
    }

    function expectClaimStackCalls(
        address borrower,
        bool claimExtras,
        bool isExternal,
        bool isMultiCall,
        uint256 numExtras
    ) internal {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            borrower
        );

        if (isMultiCall) {
            evm.expectEmit(true, false, false, false);
            emit MultiCallStarted(borrower);
        }

        if (isExternal) {
            evm.expectEmit(true, true, false, false);
            emit ExecuteOrder(
                isMultiCall ? address(creditFacade) : borrower,
                address(basePoolMock)
            );

            evm.expectCall(
                address(basePoolMock),
                abi.encodeWithSignature("getReward()")
            );
        } else {
            evm.expectCall(
                address(basePoolMock),
                abi.encodeWithSignature(
                    "getReward(address,bool)",
                    creditAccount,
                    claimExtras
                )
            );
        }

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                CreditManager.checkAndEnableToken.selector,
                creditAccount,
                crv
            )
        );

        evm.expectCall(
            address(creditManager),
            abi.encodeWithSelector(
                CreditManager.checkAndEnableToken.selector,
                creditAccount,
                cvx
            )
        );

        if (claimExtras) {
            if (numExtras >= 1) {
                evm.expectCall(
                    address(creditManager),
                    abi.encodeWithSelector(
                        CreditManager.checkAndEnableToken.selector,
                        creditAccount,
                        extraRewardToken1
                    )
                );
            }

            if (numExtras == 2) {
                evm.expectCall(
                    address(creditManager),
                    abi.encodeWithSelector(
                        CreditManager.checkAndEnableToken.selector,
                        creditAccount,
                        extraRewardToken2
                    )
                );
            }
        }

        if (isMultiCall) {
            evm.expectEmit(false, false, false, false);
            emit MultiCallFinished();
        } else {
            evm.expectCall(
                address(creditManager),
                abi.encodeWithSelector(
                    CreditManager.checkAndOptimizeEnabledTokens.selector,
                    creditAccount
                )
            );
        }
    }
}
