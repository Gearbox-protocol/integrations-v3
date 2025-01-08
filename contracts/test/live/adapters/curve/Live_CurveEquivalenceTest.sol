// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICurvePool} from "../../../../integrations/curve/ICurvePool.sol";
import {ICurvePool2Assets} from "../../../../integrations/curve/ICurvePool_2.sol";
import {ICurvePool3Assets} from "../../../../integrations/curve/ICurvePool_3.sol";
import {ICurvePool4Assets} from "../../../../integrations/curve/ICurvePool_4.sol";
import {ICurvePoolStableNG} from "../../../../integrations/curve/ICurvePool_StableNG.sol";
import {ICurveV1Adapter} from "../../../../interfaces/curve/ICurveV1Adapter.sol";
import {ICurveV1_2AssetsAdapter} from "../../../../interfaces/curve/ICurveV1_2AssetsAdapter.sol";
import {ICurveV1_3AssetsAdapter} from "../../../../interfaces/curve/ICurveV1_3AssetsAdapter.sol";
import {ICurveV1_4AssetsAdapter} from "../../../../interfaces/curve/ICurveV1_4AssetsAdapter.sol";
import {ICurveV1_StableNGAdapter} from "../../../../interfaces/curve/ICurveV1_StableNGAdapter.sol";
import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";
import {AddressList} from "@gearbox-protocol/core-v3/contracts/test/lib/AddressList.sol";

import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";

import {CurveV1Calls, CurveV1Multicaller} from "../../../multicall/curve/CurveV1_Calls.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

struct CurvePoolParams {
    bool use256;
    bool hasUnderlying;
    bool isNGPool;
    uint256 nCoins;
    address lpToken;
    bool lpSupported;
    address coin0;
    address underlying0;
    uint256 coin0BaseUnit;
    uint256 underlying0BaseUnit;
}

contract Live_CurveEquivalenceTest is LiveTestHelper {
    using CurveV1Calls for CurveV1Multicaller;
    using AddressList for address[];

    BalanceComparator comparator;

    string[] _stages;

    function setUp() public {
        // STAGES
        string[11] memory stages = [
            "after_exchange",
            "after_exchange_underlying",
            "after_exchange_diff",
            "after_exchange_diff_underlying",
            "after_add_liquidity",
            "after_remove_liquidity",
            "after_remove_liquidity_imbalance",
            "after_add_liquidity_one_coin",
            "after_add_diff_liquidity_one_coin",
            "after_remove_liquidity_one_coin",
            "after_remove_diff_liquidity_one_coin"
        ];

        /// @notice Sets comparator for this equivalence test

        uint256 len = stages.length;
        _stages = new string[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _stages[i] = stages[i];
            }
        }
    }

    /// HELPER

    function prepareComparator(address curvePoolAdapter) internal {
        address[] memory tokensToTrack = new address[](9);
        uint256 k = 3;

        tokensToTrack[0] = ICurveV1Adapter(curvePoolAdapter).token();
        tokensToTrack[1] = ICurveV1Adapter(curvePoolAdapter).token0();
        tokensToTrack[2] = ICurveV1Adapter(curvePoolAdapter).token1();

        if (ICurveV1Adapter(curvePoolAdapter).token2() != address(0)) {
            tokensToTrack[k] = ICurveV1Adapter(curvePoolAdapter).token2();
            ++k;
        }

        if (ICurveV1Adapter(curvePoolAdapter).token3() != address(0)) {
            tokensToTrack[k] = ICurveV1Adapter(curvePoolAdapter).token3();
            ++k;
        }

        if (ICurveV1Adapter(curvePoolAdapter).underlying0() != address(0)) {
            tokensToTrack[k] = ICurveV1Adapter(curvePoolAdapter).underlying0();
            ++k;
        }

        if (ICurveV1Adapter(curvePoolAdapter).underlying1() != address(0)) {
            tokensToTrack[k] = ICurveV1Adapter(curvePoolAdapter).underlying1();
            ++k;
        }

        if (ICurveV1Adapter(curvePoolAdapter).underlying2() != address(0)) {
            tokensToTrack[k] = ICurveV1Adapter(curvePoolAdapter).underlying2();
            ++k;
        }

        if (ICurveV1Adapter(curvePoolAdapter).underlying3() != address(0)) {
            tokensToTrack[k] = ICurveV1Adapter(curvePoolAdapter).underlying2();
            ++k;
        }

        tokensToTrack = tokensToTrack.trim();

        uint256[] memory _tokensToTrack = new uint256[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    function compareExchange(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);
            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.exchange(uint256(0), uint256(1), params.coin0BaseUnit, 0))
            );
        } else {
            ICurvePool pool = ICurvePool(curvePoolAddr);

            if (params.use256) {
                pool.exchange(uint256(0), uint256(1), params.coin0BaseUnit, 0);
            } else {
                pool.exchange(int128(0), int128(1), params.coin0BaseUnit, 0);
            }
        }

        comparator.takeSnapshot("after_exchange", creditAccount);
    }

    function compareExchangeUnderlying(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        if (params.hasUnderlying) {
            if (isAdapter) {
                CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);
                creditFacade.multicall(
                    creditAccount,
                    MultiCallBuilder.build(
                        pool.exchange_underlying(uint256(0), uint256(1), params.underlying0BaseUnit, 0)
                    )
                );
            } else {
                ICurvePool pool = ICurvePool(curvePoolAddr);

                if (params.use256) {
                    pool.exchange_underlying(uint256(0), uint256(1), params.underlying0BaseUnit, 0);
                } else {
                    pool.exchange_underlying(int128(0), int128(1), params.underlying0BaseUnit, 0);
                }
            }
        }

        comparator.takeSnapshot("after_exchange_underlying", creditAccount);
    }

    function compareExchangeDiff(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);
            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(pool.exchange_diff(uint256(0), uint256(1), 96 * params.coin0BaseUnit, 0))
            );
        } else {
            ICurvePool pool = ICurvePool(curvePoolAddr);

            uint256 amountToSwap = IERC20(params.coin0).balanceOf(creditAccount) - 96 * params.coin0BaseUnit;

            if (params.use256) {
                pool.exchange(uint256(0), uint256(1), amountToSwap, 0);
            } else {
                pool.exchange(int128(0), int128(1), amountToSwap, 0);
            }
        }

        comparator.takeSnapshot("after_exchange_diff", creditAccount);
    }

    function compareExchangeDiffUnderlying(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        if (params.hasUnderlying) {
            if (isAdapter) {
                CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);
                creditFacade.multicall(
                    creditAccount,
                    MultiCallBuilder.build(
                        pool.exchange_diff_underlying(uint256(0), uint256(1), 94 * params.underlying0BaseUnit, 0)
                    )
                );
            } else {
                ICurvePool pool = ICurvePool(curvePoolAddr);

                uint256 amountToSwap = IERC20(params.coin0).balanceOf(creditAccount) - 94 * params.underlying0BaseUnit;

                if (params.use256) {
                    pool.exchange_underlying(uint256(0), uint256(1), amountToSwap, 0);
                } else {
                    pool.exchange_underlying(int128(0), int128(1), amountToSwap, 0);
                }
            }
        }

        comparator.takeSnapshot("after_exchange_diff_underlying", creditAccount);
    }

    function compareAddLiquidity(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);

            if (params.isNGPool) {
                uint256[] memory amounts = new uint256[](params.nCoins);
                amounts[0] = 5 * params.coin0BaseUnit;

                creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.add_liquidity(amounts, 0)));
            } else if (params.nCoins == 2) {
                uint256[2] memory amounts = [5 * params.coin0BaseUnit, 0];

                creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.add_liquidity(amounts, 0)));
            } else if (params.nCoins == 3) {
                uint256[3] memory amounts = [5 * params.coin0BaseUnit, 0, 0];

                creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.add_liquidity(amounts, 0)));
            } else if (params.nCoins == 4) {
                uint256[4] memory amounts = [5 * params.coin0BaseUnit, 0, 0, 0];

                creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.add_liquidity(amounts, 0)));
            }
        } else {
            if (params.isNGPool) {
                ICurvePoolStableNG pool = ICurvePoolStableNG(curvePoolAddr);
                uint256[] memory amounts = new uint256[](params.nCoins);
                amounts[0] = 5 * params.coin0BaseUnit;

                pool.add_liquidity(amounts, 0);
            } else if (params.nCoins == 2) {
                ICurvePool2Assets pool = ICurvePool2Assets(curvePoolAddr);
                uint256[2] memory amounts = [5 * params.coin0BaseUnit, 0];

                pool.add_liquidity(amounts, 0);
            } else if (params.nCoins == 3) {
                ICurvePool3Assets pool = ICurvePool3Assets(curvePoolAddr);
                uint256[3] memory amounts = [5 * params.coin0BaseUnit, 0, 0];

                pool.add_liquidity(amounts, 0);
            } else if (params.nCoins == 4) {
                ICurvePool4Assets pool = ICurvePool4Assets(curvePoolAddr);
                uint256[4] memory amounts = [5 * params.coin0BaseUnit, 0, 0, 0];

                pool.add_liquidity(amounts, 0);
            }
        }

        comparator.takeSnapshot("after_add_liquidity", creditAccount);
    }

    function compareRemoveLiquidity(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        uint256 amount = IERC20(params.lpToken).balanceOf(creditAccount) / 3;

        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);

            if (params.isNGPool) {
                uint256[] memory amounts = new uint256[](params.nCoins);

                creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.remove_liquidity(amount, amounts)));
            } else if (params.nCoins == 2) {
                uint256[2] memory amounts = [uint256(0), 0];

                creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.remove_liquidity(amount, amounts)));
            } else if (params.nCoins == 3) {
                uint256[3] memory amounts = [uint256(0), 0, 0];

                creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.remove_liquidity(amount, amounts)));
            } else if (params.nCoins == 4) {
                uint256[4] memory amounts = [uint256(0), 0, 0, 0];

                creditFacade.multicall(creditAccount, MultiCallBuilder.build(pool.remove_liquidity(amount, amounts)));
            }
        } else {
            if (params.isNGPool) {
                ICurvePoolStableNG pool = ICurvePoolStableNG(curvePoolAddr);
                uint256[] memory amounts = new uint256[](params.nCoins);

                pool.remove_liquidity(amount, amounts);
            } else if (params.nCoins == 2) {
                ICurvePool2Assets pool = ICurvePool2Assets(curvePoolAddr);
                uint256[2] memory amounts = [uint256(0), 0];

                pool.remove_liquidity(amount, amounts);
            } else if (params.nCoins == 3) {
                ICurvePool3Assets pool = ICurvePool3Assets(curvePoolAddr);
                uint256[3] memory amounts = [uint256(0), 0, 0];

                pool.remove_liquidity(amount, amounts);
            } else if (params.nCoins == 4) {
                ICurvePool4Assets pool = ICurvePool4Assets(curvePoolAddr);
                uint256[4] memory amounts = [uint256(0), 0, 0, 0];

                pool.remove_liquidity(amount, amounts);
            }
        }

        comparator.takeSnapshot("after_remove_liquidity", creditAccount);
    }

    function compareRemoveLiquidityImbalance(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        uint256 maxAmount = IERC20(params.lpToken).balanceOf(creditAccount);

        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);

            if (params.isNGPool) {
                uint256[] memory amounts = new uint256[](params.nCoins);
                amounts[0] = params.coin0BaseUnit;

                creditFacade.multicall(
                    creditAccount, MultiCallBuilder.build(pool.remove_liquidity_imbalance(amounts, maxAmount))
                );
            } else if (params.nCoins == 2) {
                uint256[2] memory amounts = [params.coin0BaseUnit, 0];

                creditFacade.multicall(
                    creditAccount, MultiCallBuilder.build(pool.remove_liquidity_imbalance(amounts, maxAmount))
                );
            } else if (params.nCoins == 3) {
                uint256[3] memory amounts = [params.coin0BaseUnit, 0, 0];

                creditFacade.multicall(
                    creditAccount, MultiCallBuilder.build(pool.remove_liquidity_imbalance(amounts, maxAmount))
                );
            } else if (params.nCoins == 4) {
                uint256[4] memory amounts = [params.coin0BaseUnit, 0, 0, 0];

                creditFacade.multicall(
                    creditAccount, MultiCallBuilder.build(pool.remove_liquidity_imbalance(amounts, maxAmount))
                );
            }
        } else {
            if (params.isNGPool) {
                ICurvePoolStableNG pool = ICurvePoolStableNG(curvePoolAddr);
                uint256[] memory amounts = new uint256[](params.nCoins);
                amounts[0] = params.coin0BaseUnit;

                pool.remove_liquidity_imbalance(amounts, maxAmount);
            } else if (params.nCoins == 2) {
                ICurvePool2Assets pool = ICurvePool2Assets(curvePoolAddr);
                uint256[2] memory amounts = [params.coin0BaseUnit, 0];

                pool.remove_liquidity_imbalance(amounts, maxAmount);
            } else if (params.nCoins == 3) {
                ICurvePool3Assets pool = ICurvePool3Assets(curvePoolAddr);
                uint256[3] memory amounts = [params.coin0BaseUnit, 0, 0];

                pool.remove_liquidity_imbalance(amounts, maxAmount);
            } else if (params.nCoins == 4) {
                ICurvePool4Assets pool = ICurvePool4Assets(curvePoolAddr);
                uint256[4] memory amounts = [params.coin0BaseUnit, 0, 0, 0];

                pool.remove_liquidity_imbalance(amounts, maxAmount);
            }
        }

        comparator.takeSnapshot("after_remove_liquidity_imbalance", creditAccount);
    }

    function compareAddLiquidityOneCoin(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);
            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(pool.add_liquidity_one_coin(2 * params.coin0BaseUnit, uint256(0), 0))
            );
        } else {
            if (params.isNGPool) {
                ICurvePoolStableNG pool = ICurvePoolStableNG(curvePoolAddr);
                uint256[] memory amounts = new uint256[](params.nCoins);
                amounts[0] = 2 * params.coin0BaseUnit;

                pool.add_liquidity(amounts, 0);
            } else if (params.nCoins == 2) {
                ICurvePool2Assets pool = ICurvePool2Assets(curvePoolAddr);
                uint256[2] memory amounts = [2 * params.coin0BaseUnit, 0];

                pool.add_liquidity(amounts, 0);
            } else if (params.nCoins == 3) {
                ICurvePool3Assets pool = ICurvePool3Assets(curvePoolAddr);
                uint256[3] memory amounts = [2 * params.coin0BaseUnit, 0, 0];

                pool.add_liquidity(amounts, 0);
            } else if (params.nCoins == 4) {
                ICurvePool4Assets pool = ICurvePool4Assets(curvePoolAddr);
                uint256[4] memory amounts = [2 * params.coin0BaseUnit, 0, 0, 0];

                pool.add_liquidity(amounts, 0);
            }
        }

        comparator.takeSnapshot("after_add_liquidity_one_coin", creditAccount);
    }

    function compareAddDiffLiquidityOneCoin(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);
            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(pool.add_diff_liquidity_one_coin(70 * params.coin0BaseUnit, uint256(0), 0))
            );
        } else {
            uint256 amountToSwap = IERC20(params.coin0).balanceOf(creditAccount) - 70 * params.coin0BaseUnit;

            if (params.isNGPool) {
                ICurvePoolStableNG pool = ICurvePoolStableNG(curvePoolAddr);
                uint256[] memory amounts = new uint256[](params.nCoins);
                amounts[0] = amountToSwap;

                pool.add_liquidity(amounts, 0);
            } else if (params.nCoins == 2) {
                ICurvePool2Assets pool = ICurvePool2Assets(curvePoolAddr);
                uint256[2] memory amounts = [amountToSwap, 0];

                pool.add_liquidity(amounts, 0);
            } else if (params.nCoins == 3) {
                ICurvePool3Assets pool = ICurvePool3Assets(curvePoolAddr);
                uint256[3] memory amounts = [amountToSwap, 0, 0];

                pool.add_liquidity(amounts, 0);
            } else if (params.nCoins == 4) {
                ICurvePool4Assets pool = ICurvePool4Assets(curvePoolAddr);
                uint256[4] memory amounts = [amountToSwap, 0, 0, 0];

                pool.add_liquidity(amounts, 0);
            }
        }

        comparator.takeSnapshot("after_add_diff_liquidity_one_coin", creditAccount);
    }

    function compareRemoveLiquidityOneCoin(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        uint256 amount = IERC20(params.lpToken).balanceOf(creditAccount) / 3;

        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);
            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.remove_liquidity_one_coin(amount, uint256(0), 0))
            );
        } else {
            ICurvePool pool = ICurvePool(curvePoolAddr);

            if (params.use256) {
                pool.remove_liquidity_one_coin(amount, uint256(0), 0);
            } else {
                pool.remove_liquidity_one_coin(amount, int128(0), 0);
            }
        }

        comparator.takeSnapshot("after_remove_liquidity_one_coin", creditAccount);
    }

    function compareRemoveDiffLiquidityOneCoin(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        uint256 amount = IERC20(params.lpToken).balanceOf(creditAccount) / 3;

        if (isAdapter) {
            CurveV1Multicaller pool = CurveV1Multicaller(curvePoolAddr);
            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(pool.remove_diff_liquidity_one_coin(amount, uint256(0), 0))
            );
        } else {
            ICurvePool pool = ICurvePool(curvePoolAddr);

            uint256 amountToSwap = IERC20(params.lpToken).balanceOf(creditAccount) - amount;

            if (params.use256) {
                pool.remove_liquidity_one_coin(amountToSwap, uint256(0), 0);
            } else {
                pool.remove_liquidity_one_coin(amountToSwap, int128(0), 0);
            }
        }

        comparator.takeSnapshot("after_remove_diff_liquidity_one_coin", creditAccount);
    }

    function compareBehavior(
        address creditAccount,
        address curvePoolAddr,
        CurvePoolParams memory params,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            vm.startPrank(USER);
        } else {
            vm.startPrank(creditAccount);
        }

        compareExchange(creditAccount, curvePoolAddr, params, isAdapter);

        compareExchangeUnderlying(creditAccount, curvePoolAddr, params, isAdapter);

        compareExchangeDiff(creditAccount, curvePoolAddr, params, isAdapter);

        compareExchangeDiffUnderlying(creditAccount, curvePoolAddr, params, isAdapter);

        if (params.lpSupported) {
            compareAddLiquidity(creditAccount, curvePoolAddr, params, isAdapter);

            compareRemoveLiquidity(creditAccount, curvePoolAddr, params, isAdapter);

            compareRemoveLiquidityImbalance(creditAccount, curvePoolAddr, params, isAdapter);

            compareAddLiquidityOneCoin(creditAccount, curvePoolAddr, params, isAdapter);

            compareAddDiffLiquidityOneCoin(creditAccount, curvePoolAddr, params, isAdapter);

            compareRemoveLiquidityOneCoin(creditAccount, curvePoolAddr, params, isAdapter);

            compareRemoveDiffLiquidityOneCoin(creditAccount, curvePoolAddr, params, isAdapter);
        }

        vm.stopPrank();
    }

    /// @dev Opens credit account for USER and make amount of desired token equal
    /// amounts for USER and CA to be able to launch test for both
    function openCreditAccountWithCoinAndUnderlying(
        uint256 amountCoin0,
        uint256 amountUnderlying0,
        address coin0,
        address underlying0
    ) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);
        tokenTestSuite.mint(coin0, creditAccount, amountCoin0);
        if (underlying0 != address(0)) {
            tokenTestSuite.mint(underlying0, creditAccount, amountUnderlying0);
        }
    }

    function isCurveAdapter(bytes32 aType) internal pure returns (bool) {
        return aType == "AD_CURVE_V1_2ASSETS" || aType == "AD_CURVE_V1_3ASSETS" || aType == "AD_CURVE_V1_4ASSETS"
            || aType == "AD_CURVE_V1_STECRV_POOL" || aType == "AD_CURVE_STABLE_NG";
    }

    /// @dev [L-CRVET-1]: Curve adapter and normal account works identically
    function test_live_CRVET_01_Curve_adapter_and_normal_account_works_identically() public attachOrLiveTest {
        address[] memory adapters = creditConfigurator.allowedAdapters();

        for (uint256 i = 0; i < adapters.length; ++i) {
            if (!isCurveAdapter(IAdapter(adapters[i]).contractType())) continue;

            uint256 snapshot0 = vm.snapshot();

            address coin0 = ICurveV1Adapter(adapters[i]).token0();
            address underlying0 = ICurveV1Adapter(adapters[i]).underlying0();
            uint256 coin0BaseUnit = 10 ** IERC20Metadata(ICurveV1Adapter(adapters[i]).token0()).decimals();
            uint256 underlying0BaseUnit = underlying0 == address(0)
                ? 0
                : 10 ** IERC20Metadata(ICurveV1Adapter(adapters[i]).underlying0()).decimals();

            CurvePoolParams memory cpp = CurvePoolParams({
                use256: ICurveV1Adapter(adapters[i]).use256(),
                hasUnderlying: ICurveV1Adapter(adapters[i]).underlying0() != address(0),
                isNGPool: IAdapter(adapters[i]).contractType() == "ADAPTER::CURVE_STABLE_NG",
                nCoins: ICurveV1Adapter(adapters[i]).nCoins(),
                lpToken: ICurveV1Adapter(adapters[i]).token(),
                lpSupported: creditManager.liquidationThresholds(ICurveV1Adapter(adapters[i]).token()) != 0,
                coin0: coin0,
                underlying0: underlying0,
                coin0BaseUnit: coin0BaseUnit,
                underlying0BaseUnit: underlying0BaseUnit
            });

            address creditAccount = openCreditAccountWithCoinAndUnderlying(
                100 * coin0BaseUnit, 100 * underlying0BaseUnit, coin0, underlying0
            );

            tokenTestSuite.approve(
                ICurveV1Adapter(adapters[i]).token0(), creditAccount, ICurveV1Adapter(adapters[i]).targetContract()
            );
            if (underlying0 != address(0)) {
                tokenTestSuite.approve(
                    ICurveV1Adapter(adapters[i]).underlying0(),
                    creditAccount,
                    ICurveV1Adapter(adapters[i]).targetContract()
                );
            }

            tokenTestSuite.approve(
                ICurveV1Adapter(adapters[i]).token(), creditAccount, ICurveV1Adapter(adapters[i]).targetContract()
            );

            uint256 snapshot1 = vm.snapshot();

            prepareComparator(adapters[i]);

            compareBehavior(creditAccount, IAdapter(adapters[i]).targetContract(), cpp, false);

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot1);

            prepareComparator(adapters[i]);

            compareBehavior(creditAccount, adapters[i], cpp, true);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots, 0);

            vm.revertTo(snapshot0);
        }
    }
}
