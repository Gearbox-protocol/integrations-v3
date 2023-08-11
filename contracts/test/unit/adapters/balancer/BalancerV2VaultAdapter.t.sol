// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {PriceFeedParams} from "@gearbox-protocol/oracles-v3/contracts/oracles/AbstractPriceFeed.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {
    IBalancerV2Vault,
    PoolSpecialization,
    SingleSwap,
    BatchSwapStep,
    FundManagement,
    SwapKind,
    JoinKind,
    ExitKind,
    JoinPoolRequest,
    ExitPoolRequest
} from "../../../../integrations/balancer/IBalancerV2Vault.sol";
import {
    IBalancerV2VaultAdapter,
    IBalancerV2VaultAdapterExceptions,
    SingleSwapAll,
    PoolStatus
} from "../../../../interfaces/balancer/IBalancerV2VaultAdapter.sol";
import {IAsset} from "../../../../integrations/balancer/IAsset.sol";
import {BalancerV2VaultAdapter} from "../../../../adapters/balancer/BalancerV2VaultAdapter.sol";
import {BPTStablePriceFeed} from "@gearbox-protocol/oracles-v3/contracts/oracles/balancer/BPTStablePriceFeed.sol";
import {BPTWeightedPriceFeed} from "@gearbox-protocol/oracles-v3/contracts/oracles/balancer/BPTWeightedPriceFeed.sol";
import {IBalancerV2VaultAdapter} from "../../../../interfaces/balancer/IBalancerV2VaultAdapter.sol";
import {BalancerVaultMock} from "../../../mocks/integrations/BalancerVaultMock.sol";

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";

// TEST
import "../../../lib/constants.sol";
import {AdapterTestHelper} from "../AdapterTestHelper.sol";

bytes32 constant POOL_ID_1 = bytes32(uint256(1));
bytes32 constant POOL_ID_2 = bytes32(uint256(2));

/// @title Balancer V2 Vault adapter test
/// @notice Designed for unit test purposes only
contract BalancerV2VaultAdapterTest is AdapterTestHelper, IBalancerV2VaultAdapterExceptions {
    IBalancerV2VaultAdapter public adapter;
    BalancerVaultMock public balancerMock;
    uint256 public deadline;

    function setUp() public {
        _setUp();

        balancerMock = new BalancerVaultMock();

        address[] memory assets = new address[](3);

        assets[0] = tokenTestSuite.addressOf(Tokens.DAI);
        assets[1] = tokenTestSuite.addressOf(Tokens.USDC);
        assets[2] = tokenTestSuite.addressOf(Tokens.USDT);

        balancerMock.addStablePool(POOL_ID_1, assets, 50);

        balancerMock.setRate(
            POOL_ID_1, tokenTestSuite.addressOf(Tokens.DAI), tokenTestSuite.addressOf(Tokens.USDC), RAY / 1e12
        );

        balancerMock.setRate(
            POOL_ID_1, tokenTestSuite.addressOf(Tokens.USDT), tokenTestSuite.addressOf(Tokens.DAI), (99 * RAY) / 100
        );

        balancerMock.setRate(
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.USDT),
            tokenTestSuite.addressOf(Tokens.USDC),
            (99 * RAY) / (100 * 1e12)
        );

        balancerMock.setDepositRate(POOL_ID_1, tokenTestSuite.addressOf(Tokens.DAI), RAY);

        balancerMock.setDepositRate(POOL_ID_1, tokenTestSuite.addressOf(Tokens.USDC), RAY * 1e12);

        balancerMock.setDepositRate(POOL_ID_1, tokenTestSuite.addressOf(Tokens.USDT), RAY);

        balancerMock.setWithdrawalRate(POOL_ID_1, tokenTestSuite.addressOf(Tokens.DAI), RAY);

        balancerMock.setWithdrawalRate(POOL_ID_1, tokenTestSuite.addressOf(Tokens.USDC), RAY / 1e12);

        balancerMock.setWithdrawalRate(POOL_ID_1, tokenTestSuite.addressOf(Tokens.USDT), RAY);

        tokenTestSuite.mint(Tokens.DAI, address(balancerMock), RAY);

        tokenTestSuite.mint(Tokens.USDC, address(balancerMock), RAY);

        tokenTestSuite.mint(Tokens.USDT, address(balancerMock), RAY);

        uint256[] memory balances = new uint256[](3);

        balances[0] = 10000000 * WAD;
        balances[1] = 10000000 * 1e6;
        balances[2] = 10000000 * WAD;

        balancerMock.setAssetBalances(POOL_ID_1, balances);

        (address bpt,) = balancerMock.getPool(POOL_ID_1);

        PriceFeedParams[5] memory priceFeeds;
        priceFeeds[0] = PriceFeedParams({priceFeed: priceOracle.priceFeeds(assets[0]), stalenessPeriod: 48 hours});
        priceFeeds[1] = PriceFeedParams({priceFeed: priceOracle.priceFeeds(assets[1]), stalenessPeriod: 48 hours});
        priceFeeds[2] = PriceFeedParams({priceFeed: priceOracle.priceFeeds(assets[2]), stalenessPeriod: 48 hours});

        address bptPf = address(
            new BPTStablePriceFeed(
                address(addressProvider),
                bpt,
                priceFeeds
            )
        );

        vm.startPrank(CONFIGURATOR);

        priceOracle.setPriceFeed(bpt, bptPf, 0);
        creditConfigurator.addCollateralToken(bpt, 9000);

        vm.stopPrank();

        assets = new address[](2);

        assets[0] = tokenTestSuite.addressOf(Tokens.DAI);
        assets[1] = tokenTestSuite.addressOf(Tokens.WETH);

        uint256[] memory weights = new uint256[](2);

        weights[0] = WAD / 2;
        weights[1] = WAD / 2;

        balancerMock.addPool(POOL_ID_2, assets, weights, PoolSpecialization.MINIMAL_SWAP_INFO, 50);

        balancerMock.setRate(
            POOL_ID_2, tokenTestSuite.addressOf(Tokens.DAI), tokenTestSuite.addressOf(Tokens.WETH), RAY / DAI_WETH_RATE
        );

        balancerMock.setDepositRate(POOL_ID_2, tokenTestSuite.addressOf(Tokens.DAI), RAY);

        balancerMock.setWithdrawalRate(POOL_ID_2, tokenTestSuite.addressOf(Tokens.DAI), RAY);

        balancerMock.setDepositRate(POOL_ID_2, tokenTestSuite.addressOf(Tokens.WETH), RAY * DAI_WETH_RATE);

        balancerMock.setWithdrawalRate(POOL_ID_2, tokenTestSuite.addressOf(Tokens.WETH), RAY / DAI_WETH_RATE);

        tokenTestSuite.mint(Tokens.DAI, address(balancerMock), RAY);

        tokenTestSuite.mint(Tokens.WETH, address(balancerMock), RAY);

        balances = new uint256[](2);

        balances[0] = 10000000 * WAD;
        balances[1] = balances[0] / DAI_WETH_RATE;

        balancerMock.setAssetBalances(POOL_ID_2, balances);

        balancerMock.mintBPT(POOL_ID_2, FRIEND2, 20000000 * WAD);

        (bpt,) = balancerMock.getPool(POOL_ID_2);

        PriceFeedParams[] memory priceFeeds2 = new PriceFeedParams[](2);

        priceFeeds2[0] = PriceFeedParams({priceFeed: priceOracle.priceFeeds(assets[0]), stalenessPeriod: 48 hours});
        priceFeeds2[1] = PriceFeedParams({priceFeed: priceOracle.priceFeeds(assets[1]), stalenessPeriod: 48 hours});

        bptPf = address(
            new BPTWeightedPriceFeed(
                address(addressProvider),
                address(balancerMock),
                bpt,
                priceFeeds2
            )
        );

        vm.startPrank(CONFIGURATOR);

        priceOracle.setPriceFeed(bpt, bptPf, 0);
        creditConfigurator.addCollateralToken(bpt, 9000);

        vm.stopPrank();

        adapter = new BalancerV2VaultAdapter(
            address(creditManager),
            address(balancerMock)
        );

        vm.prank(CONFIGURATOR);
        creditConfigurator.allowAdapter(address(adapter));

        vm.label(address(adapter), "ADAPTER");
        vm.label(address(balancerMock), "BALANCER_MOCK");

        vm.startPrank(CONFIGURATOR);
        BalancerV2VaultAdapter(address(adapter)).setPoolIDStatus(POOL_ID_1, PoolStatus.ALLOWED);
        BalancerV2VaultAdapter(address(adapter)).setPoolIDStatus(POOL_ID_2, PoolStatus.ALLOWED);
        vm.stopPrank();

        deadline = _getUniswapDeadline();
    }

    function _standardFundManagement(address creditAccount) internal pure returns (FundManagement memory) {
        return FundManagement({
            sender: creditAccount,
            fromInternalBalance: false,
            recipient: payable(creditAccount),
            toInternalBalance: false
        });
    }

    function expectBatchSwapStackCalls(
        address targetContract,
        address borrower,
        address creditAccount,
        bytes memory callData,
        IAsset[] memory assets,
        int256[] memory limits
    ) internal {
        vm.expectEmit(true, false, false, false);
        emit StartMultiCall(creditAccount, borrower);

        for (uint256 i = 0; i < assets.length; ++i) {
            if (limits[i] > 1) {
                vm.expectCall(
                    address(creditManager),
                    abi.encodeCall(ICreditManagerV3.approveCreditAccount, (address(assets[i]), type(uint256).max))
                );
            }
        }

        vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.execute, (callData)));

        vm.expectEmit(true, false, false, false);
        emit Execute(creditAccount, targetContract);

        for (uint256 i = 0; i < assets.length; ++i) {
            if (limits[i] > 1) {
                vm.expectCall(
                    address(creditManager),
                    abi.encodeCall(ICreditManagerV3.approveCreditAccount, (address(assets[i]), 1))
                );
            }
        }

        vm.expectEmit(false, false, false, false);
        emit FinishMultiCall();
    }

    function expectJoinPoolStackCalls(
        address targetContract,
        address borrower,
        address creditAccount,
        bytes32 poolId,
        bytes memory callData,
        IAsset[] memory assets,
        uint256[] memory maxAmountsIn
    ) internal {
        vm.expectEmit(true, false, false, false);
        emit StartMultiCall(creditAccount, borrower);

        for (uint256 i = 0; i < assets.length; ++i) {
            if (maxAmountsIn[i] > 1) {
                vm.expectCall(
                    address(creditManager),
                    abi.encodeCall(ICreditManagerV3.approveCreditAccount, (address(assets[i]), type(uint256).max))
                );
            }
        }

        (address pool,) = balancerMock.getPool(poolId);

        vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.execute, (callData)));

        vm.expectEmit(true, false, false, false);
        emit Execute(creditAccount, targetContract);

        for (uint256 i = 0; i < assets.length; ++i) {
            if (maxAmountsIn[i] > 1) {
                vm.expectCall(
                    address(creditManager),
                    abi.encodeCall(ICreditManagerV3.approveCreditAccount, (address(assets[i]), 1))
                );
            }
        }

        vm.expectEmit(false, false, false, false);
        emit FinishMultiCall();
    }

    function expectExitPoolStackCalls(
        address targetContract,
        address borrower,
        address creditAccount,
        bytes memory callData,
        IAsset[] memory assets
    ) internal {
        vm.expectEmit(true, false, false, false);
        emit StartMultiCall(creditAccount, borrower);

        vm.expectCall(address(creditManager), abi.encodeCall(ICreditManagerV3.execute, (callData)));

        vm.expectEmit(true, false, false, false);
        emit Execute(creditAccount, targetContract);

        vm.expectEmit(false, false, false, false);
        emit FinishMultiCall();
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [ABV2-1]: swap works as expected
    function test_ABV2_01_swap_works_as_expected() public {
        setUp();
        (address creditAccount, uint256 initialDAIBalance) = _openTestCreditAccount();

        FundManagement memory fundManagement =
            FundManagement({sender: USER, fromInternalBalance: true, recipient: payable(USER), toInternalBalance: true});

        SingleSwap memory singleSwapData = SingleSwap({
            poolId: POOL_ID_2,
            kind: SwapKind.GIVEN_IN,
            assetIn: IAsset(tokenTestSuite.addressOf(Tokens.DAI)),
            assetOut: IAsset(tokenTestSuite.addressOf(Tokens.WETH)),
            amount: DAI_EXCHANGE_AMOUNT,
            userData: ""
        });

        expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 0);

        expectAllowance(Tokens.WETH, creditAccount, address(balancerMock), 0);

        bytes memory expectedCallData = abi.encodeWithSelector(
            IBalancerV2Vault.swap.selector,
            singleSwapData,
            _standardFundManagement(creditAccount),
            DAI_EXCHANGE_AMOUNT / (DAI_WETH_RATE * 2),
            deadline
        );

        bytes memory passedCallData = abi.encodeWithSelector(
            IBalancerV2Vault.swap.selector,
            singleSwapData,
            fundManagement,
            DAI_EXCHANGE_AMOUNT / (DAI_WETH_RATE * 2),
            deadline
        );

        expectMulticallStackCalls(
            address(adapter),
            address(balancerMock),
            USER,
            expectedCallData,
            tokenTestSuite.addressOf(Tokens.DAI),
            tokenTestSuite.addressOf(Tokens.WETH),
            true
        );

        executeOneLineMulticall(creditAccount, address(adapter), passedCallData);

        expectBalance(Tokens.DAI, creditAccount, initialDAIBalance - DAI_EXCHANGE_AMOUNT);

        expectBalance(Tokens.WETH, creditAccount, ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 9950) / 10000);

        expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 1);

        expectTokenIsEnabled(creditAccount, Tokens.WETH, true);
    }

    /// @dev [ABV2-2]: swapAll works as expected
    function test_ABV2_02_swapAll_works_as_expected() public {
        setUp();
        (address creditAccount, uint256 initialDAIBalance) = _openTestCreditAccount();

        SingleSwapAll memory singleSwapAllData = SingleSwapAll({
            poolId: POOL_ID_2,
            assetIn: IAsset(tokenTestSuite.addressOf(Tokens.DAI)),
            assetOut: IAsset(tokenTestSuite.addressOf(Tokens.WETH)),
            userData: ""
        });

        SingleSwap memory expectedSingleSwapData = SingleSwap({
            poolId: POOL_ID_2,
            kind: SwapKind.GIVEN_IN,
            assetIn: IAsset(tokenTestSuite.addressOf(Tokens.DAI)),
            assetOut: IAsset(tokenTestSuite.addressOf(Tokens.WETH)),
            amount: initialDAIBalance - 1,
            userData: ""
        });

        bytes memory expectedCallData = abi.encodeWithSelector(
            IBalancerV2Vault.swap.selector,
            expectedSingleSwapData,
            _standardFundManagement(creditAccount),
            (initialDAIBalance - 1) / (DAI_WETH_RATE * 2),
            deadline
        );

        bytes memory passedCallData = abi.encodeWithSelector(
            IBalancerV2VaultAdapter.swapAll.selector, singleSwapAllData, RAY / (DAI_WETH_RATE * 2), deadline
        );

        expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 0);

        expectAllowance(Tokens.WETH, creditAccount, address(balancerMock), 0);

        expectMulticallStackCalls(
            address(adapter),
            address(balancerMock),
            USER,
            expectedCallData,
            tokenTestSuite.addressOf(Tokens.DAI),
            tokenTestSuite.addressOf(Tokens.WETH),
            true
        );

        executeOneLineMulticall(creditAccount, address(adapter), passedCallData);

        expectBalance(Tokens.DAI, creditAccount, 1);

        expectBalance(Tokens.WETH, creditAccount, (((initialDAIBalance - 1) / DAI_WETH_RATE) * 9950) / 10000);

        expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 1);

        expectTokenIsEnabled(creditAccount, Tokens.DAI, false);
        expectTokenIsEnabled(creditAccount, Tokens.WETH, true);
    }

    /// @dev [ABV2-3]: batchSwap works as expected
    function test_ABV2_03_batchSwap_works_as_expected() public {
        for (uint256 st = 0; st < 3; ++st) {
            // ST is swap type
            // 0 = single swap from DAI to WETH
            // 1 = parallel swap from DAI to WETH and USDC
            // 2 = consecutive swap from WETH to DAI to USDC

            setUp();
            (address creditAccount, uint256 initialDAIBalance) = _openTestCreditAccount();

            BatchSwapStep[] memory batchSteps;
            IAsset[] memory assets;
            int256[] memory limits;

            if (st == 0) {
                batchSteps = new BatchSwapStep[](1);
                assets = new IAsset[](2);
                limits = new int256[](2);

                assets[0] = IAsset(tokenTestSuite.addressOf(Tokens.DAI));
                assets[1] = IAsset(tokenTestSuite.addressOf(Tokens.WETH));

                limits[0] = int256(DAI_EXCHANGE_AMOUNT);
                limits[1] = -int256(DAI_EXCHANGE_AMOUNT / (2 * DAI_WETH_RATE));

                batchSteps[0] = BatchSwapStep({
                    poolId: POOL_ID_2,
                    assetInIndex: 0,
                    assetOutIndex: 1,
                    amount: DAI_EXCHANGE_AMOUNT,
                    userData: ""
                });
            } else if (st == 1) {
                batchSteps = new BatchSwapStep[](2);

                assets = new IAsset[](3);
                limits = new int256[](3);

                assets[0] = IAsset(tokenTestSuite.addressOf(Tokens.DAI));
                assets[1] = IAsset(tokenTestSuite.addressOf(Tokens.WETH));
                assets[2] = IAsset(tokenTestSuite.addressOf(Tokens.USDC));

                limits[0] = int256(DAI_EXCHANGE_AMOUNT * 2);
                limits[1] = -int256(DAI_EXCHANGE_AMOUNT / (2 * DAI_WETH_RATE));
                limits[2] = -int256(DAI_EXCHANGE_AMOUNT / (2 * 1e12));

                batchSteps[0] = BatchSwapStep({
                    poolId: POOL_ID_2,
                    assetInIndex: 0,
                    assetOutIndex: 1,
                    amount: DAI_EXCHANGE_AMOUNT,
                    userData: ""
                });

                batchSteps[1] = BatchSwapStep({
                    poolId: POOL_ID_1,
                    assetInIndex: 0,
                    assetOutIndex: 2,
                    amount: DAI_EXCHANGE_AMOUNT,
                    userData: ""
                });
            } else if (st == 2) {
                addCollateral(Tokens.WETH, WETH_ACCOUNT_AMOUNT);
                batchSteps = new BatchSwapStep[](2);

                assets = new IAsset[](3);
                limits = new int256[](3);

                assets[0] = IAsset(tokenTestSuite.addressOf(Tokens.DAI));
                assets[1] = IAsset(tokenTestSuite.addressOf(Tokens.WETH));
                assets[2] = IAsset(tokenTestSuite.addressOf(Tokens.USDC));

                limits[0] = 0;
                limits[1] = int256(WETH_EXCHANGE_AMOUNT);
                limits[2] = (-int256(WETH_EXCHANGE_AMOUNT * DAI_WETH_RATE)) / (2 * 1e12);

                batchSteps[0] = BatchSwapStep({
                    poolId: POOL_ID_2,
                    assetInIndex: 1,
                    assetOutIndex: 0,
                    amount: WETH_EXCHANGE_AMOUNT,
                    userData: ""
                });

                batchSteps[1] =
                    BatchSwapStep({poolId: POOL_ID_1, assetInIndex: 0, assetOutIndex: 2, amount: 0, userData: ""});
            }

            FundManagement memory fundManagement = FundManagement({
                sender: USER,
                fromInternalBalance: true,
                recipient: payable(USER),
                toInternalBalance: true
            });

            expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 0);

            expectAllowance(Tokens.WETH, creditAccount, address(balancerMock), 0);

            bytes memory expectedCallData = abi.encodeWithSelector(
                IBalancerV2Vault.batchSwap.selector,
                SwapKind.GIVEN_IN,
                batchSteps,
                assets,
                _standardFundManagement(creditAccount),
                limits,
                deadline
            );

            expectBatchSwapStackCalls(address(balancerMock), USER, creditAccount, expectedCallData, assets, limits);

            executeOneLineMulticall(
                creditAccount,
                address(adapter),
                abi.encodeWithSelector(
                    IBalancerV2Vault.batchSwap.selector,
                    SwapKind.GIVEN_IN,
                    batchSteps,
                    assets,
                    fundManagement,
                    limits,
                    deadline
                )
            );

            if (st == 0) {
                expectBalance(Tokens.DAI, creditAccount, initialDAIBalance - DAI_EXCHANGE_AMOUNT);

                expectBalance(Tokens.WETH, creditAccount, ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 9950) / 10000);

                expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 1);

                expectAllowance(Tokens.WETH, creditAccount, address(balancerMock), 0);

                expectTokenIsEnabled(creditAccount, Tokens.WETH, true);
            } else if (st == 1) {
                expectBalance(Tokens.DAI, creditAccount, initialDAIBalance - 2 * DAI_EXCHANGE_AMOUNT);

                expectBalance(Tokens.WETH, creditAccount, ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 9950) / 10000);

                expectBalance(Tokens.USDC, creditAccount, ((DAI_EXCHANGE_AMOUNT / 1e12) * 9950) / 10000);

                expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 1);

                expectAllowance(Tokens.WETH, creditAccount, address(balancerMock), 0);

                expectAllowance(Tokens.USDC, creditAccount, address(balancerMock), 0);

                expectTokenIsEnabled(creditAccount, Tokens.WETH, true);
                expectTokenIsEnabled(creditAccount, Tokens.USDC, true);
            } else if (st == 2) {
                expectBalance(Tokens.WETH, creditAccount, WETH_ACCOUNT_AMOUNT - WETH_EXCHANGE_AMOUNT);
                expectBalance(Tokens.DAI, creditAccount, initialDAIBalance);

                uint256 expectedAmount = (WETH_EXCHANGE_AMOUNT * DAI_WETH_RATE * 9950) / 10000;
                expectedAmount = ((expectedAmount / 1e12) * 9950) / 10000;

                expectBalance(Tokens.USDC, creditAccount, expectedAmount);
                expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 0);

                expectAllowance(Tokens.WETH, creditAccount, address(balancerMock), 1);

                expectAllowance(Tokens.USDC, creditAccount, address(balancerMock), 0);

                expectTokenIsEnabled(creditAccount, Tokens.USDC, true);
            }
        }
    }

    /// @dev [ABV2-4]: joinPool works as expected
    function test_ABV2_04_joinPool_works_as_expected() public {
        setUp();
        (address creditAccount, uint256 initialDAIBalance) = _openTestCreditAccount();

        addCollateral(Tokens.USDT, DAI_ACCOUNT_AMOUNT);

        IAsset[] memory assets = new IAsset[](3);

        assets[0] = IAsset(tokenTestSuite.addressOf(Tokens.DAI));
        assets[1] = IAsset(tokenTestSuite.addressOf(Tokens.USDC));
        assets[2] = IAsset(tokenTestSuite.addressOf(Tokens.USDT));

        uint256[] memory maxAmountsIn = new uint256[](3);

        maxAmountsIn[0] = DAI_EXCHANGE_AMOUNT;
        maxAmountsIn[1] = 0;
        maxAmountsIn[2] = DAI_EXCHANGE_AMOUNT;

        JoinPoolRequest memory request;

        {
            bytes memory userData = abi.encode(JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, DAI_EXCHANGE_AMOUNT);

            request = JoinPoolRequest({
                assets: assets,
                maxAmountsIn: maxAmountsIn,
                userData: userData,
                fromInternalBalance: true
            });
        }

        bytes memory passedCallData =
            abi.encodeWithSelector(IBalancerV2Vault.joinPool.selector, POOL_ID_1, USER, USER, request);

        request.fromInternalBalance = false;

        bytes memory expectedCallData =
            abi.encodeWithSelector(IBalancerV2Vault.joinPool.selector, POOL_ID_1, creditAccount, creditAccount, request);

        request.fromInternalBalance = true;

        expectJoinPoolStackCalls(
            address(balancerMock), USER, creditAccount, POOL_ID_1, expectedCallData, assets, maxAmountsIn
        );

        executeOneLineMulticall(creditAccount, address(adapter), passedCallData);

        expectBalance(Tokens.DAI, creditAccount, initialDAIBalance - DAI_EXCHANGE_AMOUNT);
        expectBalance(Tokens.USDT, creditAccount, DAI_ACCOUNT_AMOUNT - DAI_EXCHANGE_AMOUNT);

        (address pool,) = balancerMock.getPool(POOL_ID_1);

        expectBalance(pool, creditAccount, DAI_EXCHANGE_AMOUNT * 2);

        expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 1);

        expectAllowance(Tokens.USDT, creditAccount, address(balancerMock), 1);

        expectTokenIsEnabled(creditAccount, pool, true);
    }

    /// @dev [ABV2-5]: joinPoolSingleAsset works as expected
    function test_ABV2_05_joinPoolSingleAsset_works_as_expected() public {
        setUp();
        (address creditAccount, uint256 initialDAIBalance) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 0);

        bytes memory passedCallData = abi.encodeWithSelector(
            IBalancerV2VaultAdapter.joinPoolSingleAsset.selector,
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.DAI),
            DAI_EXCHANGE_AMOUNT,
            DAI_EXCHANGE_AMOUNT / 2
        );

        IAsset[] memory assets = new IAsset[](3);

        assets[0] = IAsset(tokenTestSuite.addressOf(Tokens.DAI));
        assets[1] = IAsset(tokenTestSuite.addressOf(Tokens.USDC));
        assets[2] = IAsset(tokenTestSuite.addressOf(Tokens.USDT));

        uint256[] memory maxAmountsIn = new uint256[](3);

        maxAmountsIn[0] = DAI_EXCHANGE_AMOUNT;

        JoinPoolRequest memory request;

        {
            bytes memory userData =
                abi.encode(JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, DAI_EXCHANGE_AMOUNT / 2);

            request = JoinPoolRequest({
                assets: assets,
                maxAmountsIn: maxAmountsIn,
                userData: userData,
                fromInternalBalance: false
            });
        }

        bytes memory expectedCallData =
            abi.encodeWithSelector(IBalancerV2Vault.joinPool.selector, POOL_ID_1, creditAccount, creditAccount, request);

        (address pool,) = balancerMock.getPool(POOL_ID_1);

        expectMulticallStackCalls(
            address(adapter),
            address(balancerMock),
            USER,
            expectedCallData,
            tokenTestSuite.addressOf(Tokens.DAI),
            pool,
            true
        );

        executeOneLineMulticall(creditAccount, address(adapter), passedCallData);

        expectBalance(Tokens.DAI, creditAccount, initialDAIBalance - DAI_EXCHANGE_AMOUNT);

        expectBalance(pool, creditAccount, DAI_EXCHANGE_AMOUNT);

        expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 1);

        expectTokenIsEnabled(creditAccount, pool, true);
    }

    /// @dev [ABV2-6]: joinPoolSingleAssetAll works as expected
    function test_ABV2_06_joinPoolSingleAssetAll_works_as_expected() public {
        setUp();
        (address creditAccount, uint256 initialDAIBalance) = _openTestCreditAccount();

        expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 0);

        bytes memory passedCallData = abi.encodeWithSelector(
            IBalancerV2VaultAdapter.joinPoolSingleAssetAll.selector,
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.DAI),
            RAY / 2
        );

        IAsset[] memory assets = new IAsset[](3);

        assets[0] = IAsset(tokenTestSuite.addressOf(Tokens.DAI));
        assets[1] = IAsset(tokenTestSuite.addressOf(Tokens.USDC));
        assets[2] = IAsset(tokenTestSuite.addressOf(Tokens.USDT));

        uint256[] memory maxAmountsIn = new uint256[](3);

        maxAmountsIn[0] = initialDAIBalance - 1;

        JoinPoolRequest memory request;

        {
            bytes memory userData =
                abi.encode(JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, (initialDAIBalance - 1) / 2);

            request = JoinPoolRequest({
                assets: assets,
                maxAmountsIn: maxAmountsIn,
                userData: userData,
                fromInternalBalance: false
            });
        }

        bytes memory expectedCallData =
            abi.encodeWithSelector(IBalancerV2Vault.joinPool.selector, POOL_ID_1, creditAccount, creditAccount, request);

        (address pool,) = balancerMock.getPool(POOL_ID_1);

        expectMulticallStackCalls(
            address(adapter),
            address(balancerMock),
            USER,
            expectedCallData,
            tokenTestSuite.addressOf(Tokens.DAI),
            pool,
            true
        );

        executeOneLineMulticall(creditAccount, address(adapter), passedCallData);

        expectBalance(Tokens.DAI, creditAccount, 1);

        expectBalance(pool, creditAccount, initialDAIBalance - 1);

        expectAllowance(Tokens.DAI, creditAccount, address(balancerMock), 1);

        expectTokenIsEnabled(creditAccount, pool, true);
    }

    /// @dev [ABV2-7]: exitPool works as expected
    function test_ABV2_07_exitPool_works_as_expected() public {
        setUp();
        (address creditAccount, uint256 initialDAIBalance) = _openTestCreditAccount();

        balancerMock.mintBPT(POOL_ID_1, creditAccount, 50000 * WAD);

        IAsset[] memory assets = new IAsset[](3);

        assets[0] = IAsset(tokenTestSuite.addressOf(Tokens.DAI));
        assets[1] = IAsset(tokenTestSuite.addressOf(Tokens.USDC));
        assets[2] = IAsset(tokenTestSuite.addressOf(Tokens.USDT));

        uint256[] memory minAmountsOut = new uint256[](3);

        minAmountsOut[0] = 9000 * WAD;
        minAmountsOut[1] = 9000 * 1e6;
        minAmountsOut[2] = 9000 * WAD;

        ExitPoolRequest memory request;

        {
            bytes memory userData = abi.encode(ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, 30000 * WAD);

            request = ExitPoolRequest({
                assets: assets,
                minAmountsOut: minAmountsOut,
                userData: userData,
                toInternalBalance: true
            });
        }

        bytes memory passedCallData =
            abi.encodeWithSelector(IBalancerV2Vault.exitPool.selector, POOL_ID_1, USER, USER, request);

        request.toInternalBalance = false;

        bytes memory expectedCallData =
            abi.encodeWithSelector(IBalancerV2Vault.exitPool.selector, POOL_ID_1, creditAccount, creditAccount, request);

        request.toInternalBalance = true;

        expectExitPoolStackCalls(address(balancerMock), USER, creditAccount, expectedCallData, assets);

        executeOneLineMulticall(creditAccount, address(adapter), passedCallData);

        expectBalance(Tokens.DAI, creditAccount, initialDAIBalance + 10000 * WAD);
        expectBalance(Tokens.USDT, creditAccount, 10000 * WAD);
        expectBalance(Tokens.USDC, creditAccount, 10000 * 1e6);

        (address pool,) = balancerMock.getPool(POOL_ID_1);

        expectBalance(pool, creditAccount, 20000 * WAD);

        expectTokenIsEnabled(creditAccount, Tokens.DAI, true);
        expectTokenIsEnabled(creditAccount, Tokens.USDC, true);
        expectTokenIsEnabled(creditAccount, Tokens.USDT, true);
    }

    /// @dev [ABV2-8]: exitPoolSingleAsset works as expected
    function test_ABV2_08_exitPoolSingleAsset_works_as_expected() public {
        setUp();
        (address creditAccount,) = _openTestCreditAccount();

        balancerMock.mintBPT(POOL_ID_1, creditAccount, DAI_ACCOUNT_AMOUNT);

        bytes memory passedCallData = abi.encodeWithSelector(
            IBalancerV2VaultAdapter.exitPoolSingleAsset.selector,
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.USDT),
            DAI_EXCHANGE_AMOUNT,
            DAI_EXCHANGE_AMOUNT / 2
        );

        IAsset[] memory assets = new IAsset[](3);

        assets[0] = IAsset(tokenTestSuite.addressOf(Tokens.DAI));
        assets[1] = IAsset(tokenTestSuite.addressOf(Tokens.USDC));
        assets[2] = IAsset(tokenTestSuite.addressOf(Tokens.USDT));

        uint256[] memory minAmountsOut = new uint256[](3);

        minAmountsOut[2] = DAI_EXCHANGE_AMOUNT / 2;

        ExitPoolRequest memory request;

        {
            bytes memory userData = abi.encode(ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, DAI_EXCHANGE_AMOUNT, 2);

            request = ExitPoolRequest({
                assets: assets,
                minAmountsOut: minAmountsOut,
                userData: userData,
                toInternalBalance: false
            });
        }

        bytes memory expectedCallData =
            abi.encodeWithSelector(IBalancerV2Vault.exitPool.selector, POOL_ID_1, creditAccount, creditAccount, request);

        (address pool,) = balancerMock.getPool(POOL_ID_1);

        expectMulticallStackCalls(
            address(adapter),
            address(balancerMock),
            USER,
            expectedCallData,
            pool,
            tokenTestSuite.addressOf(Tokens.USDT),
            false
        );

        executeOneLineMulticall(creditAccount, address(adapter), passedCallData);

        expectBalance(Tokens.USDT, creditAccount, DAI_EXCHANGE_AMOUNT);

        expectBalance(pool, creditAccount, DAI_ACCOUNT_AMOUNT - DAI_EXCHANGE_AMOUNT);

        expectTokenIsEnabled(creditAccount, Tokens.USDT, true);
    }

    /// @dev [ABV2-9]: exitPoolSingleAssetAll works as expected
    function test_ABV2_09_exitPoolSingleAssetAll_works_as_expected() public {
        setUp();
        (address creditAccount,) = _openTestCreditAccount();

        balancerMock.mintBPT(POOL_ID_1, creditAccount, DAI_ACCOUNT_AMOUNT);

        bytes memory passedCallData = abi.encodeWithSelector(
            IBalancerV2VaultAdapter.exitPoolSingleAssetAll.selector,
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.USDT),
            RAY / 2
        );

        IAsset[] memory assets = new IAsset[](3);

        assets[0] = IAsset(tokenTestSuite.addressOf(Tokens.DAI));
        assets[1] = IAsset(tokenTestSuite.addressOf(Tokens.USDC));
        assets[2] = IAsset(tokenTestSuite.addressOf(Tokens.USDT));

        uint256[] memory minAmountsOut = new uint256[](3);

        minAmountsOut[2] = (DAI_ACCOUNT_AMOUNT - 1) / 2;

        ExitPoolRequest memory request;

        {
            bytes memory userData = abi.encode(ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, DAI_ACCOUNT_AMOUNT - 1, 2);

            request = ExitPoolRequest({
                assets: assets,
                minAmountsOut: minAmountsOut,
                userData: userData,
                toInternalBalance: false
            });
        }

        bytes memory expectedCallData =
            abi.encodeWithSelector(IBalancerV2Vault.exitPool.selector, POOL_ID_1, creditAccount, creditAccount, request);

        (address pool,) = balancerMock.getPool(POOL_ID_1);

        expectMulticallStackCalls(
            address(adapter),
            address(balancerMock),
            USER,
            expectedCallData,
            pool,
            tokenTestSuite.addressOf(Tokens.USDT),
            false
        );

        executeOneLineMulticall(creditAccount, address(adapter), passedCallData);

        expectBalance(Tokens.USDT, creditAccount, DAI_ACCOUNT_AMOUNT - 1);

        expectBalance(pool, creditAccount, 1);

        expectTokenIsEnabled(creditAccount, Tokens.USDT, true);
    }

    /// @dev [ABV2-10]: swap and joinPool functions revert when the pool doesn't have appropriate status
    function test_ABV2_10_swap_join_revert_on_poolId_status() public {
        (address creditAccount, uint256 initialDAIBalance) = _openTestCreditAccount();

        vm.startPrank(CONFIGURATOR);
        BalancerV2VaultAdapter(address(adapter)).setPoolIDStatus(POOL_ID_1, PoolStatus.SWAP_ONLY);
        BalancerV2VaultAdapter(address(adapter)).setPoolIDStatus(POOL_ID_2, PoolStatus.NOT_ALLOWED);
        vm.stopPrank();

        {
            FundManagement memory fundManagement = FundManagement({
                sender: USER,
                fromInternalBalance: true,
                recipient: payable(USER),
                toInternalBalance: true
            });

            SingleSwap memory singleSwapData = SingleSwap({
                poolId: POOL_ID_2,
                kind: SwapKind.GIVEN_IN,
                assetIn: IAsset(tokenTestSuite.addressOf(Tokens.DAI)),
                assetOut: IAsset(tokenTestSuite.addressOf(Tokens.WETH)),
                amount: DAI_EXCHANGE_AMOUNT,
                userData: ""
            });

            bytes memory passedCallData = abi.encodeWithSelector(
                IBalancerV2Vault.swap.selector,
                singleSwapData,
                fundManagement,
                DAI_EXCHANGE_AMOUNT / (DAI_WETH_RATE * 2),
                deadline
            );

            vm.expectRevert(PoolIDNotSupportedException.selector);
            executeOneLineMulticall(creditAccount, address(adapter), passedCallData);
        }

        {
            SingleSwapAll memory singleSwapAllData = SingleSwapAll({
                poolId: POOL_ID_2,
                assetIn: IAsset(tokenTestSuite.addressOf(Tokens.DAI)),
                assetOut: IAsset(tokenTestSuite.addressOf(Tokens.WETH)),
                userData: ""
            });

            bytes memory passedCallData = abi.encodeWithSelector(
                IBalancerV2VaultAdapter.swapAll.selector, singleSwapAllData, RAY / (DAI_WETH_RATE * 2), deadline
            );

            vm.expectRevert(PoolIDNotSupportedException.selector);
            executeOneLineMulticall(creditAccount, address(adapter), passedCallData);
        }

        {
            BatchSwapStep[] memory batchSteps = new BatchSwapStep[](2);

            IAsset[] memory assets = new IAsset[](3);
            int256[] memory limits = new int256[](3);

            assets[0] = IAsset(tokenTestSuite.addressOf(Tokens.DAI));
            assets[1] = IAsset(tokenTestSuite.addressOf(Tokens.WETH));
            assets[2] = IAsset(tokenTestSuite.addressOf(Tokens.USDC));

            limits[0] = 0;
            limits[1] = int256(WETH_EXCHANGE_AMOUNT);
            limits[2] = (-int256(WETH_EXCHANGE_AMOUNT * DAI_WETH_RATE)) / (2 * 1e12);

            batchSteps[0] = BatchSwapStep({
                poolId: POOL_ID_2,
                assetInIndex: 1,
                assetOutIndex: 0,
                amount: WETH_EXCHANGE_AMOUNT,
                userData: ""
            });

            batchSteps[1] =
                BatchSwapStep({poolId: POOL_ID_1, assetInIndex: 0, assetOutIndex: 2, amount: 0, userData: ""});

            FundManagement memory fundManagement = FundManagement({
                sender: USER,
                fromInternalBalance: true,
                recipient: payable(USER),
                toInternalBalance: true
            });

            vm.expectRevert(PoolIDNotSupportedException.selector);
            executeOneLineMulticall(
                creditAccount,
                address(adapter),
                abi.encodeWithSelector(
                    IBalancerV2Vault.batchSwap.selector,
                    SwapKind.GIVEN_IN,
                    batchSteps,
                    assets,
                    fundManagement,
                    limits,
                    deadline
                )
            );
        }

        {
            IAsset[] memory assets = new IAsset[](3);

            assets[0] = IAsset(tokenTestSuite.addressOf(Tokens.DAI));
            assets[1] = IAsset(tokenTestSuite.addressOf(Tokens.USDC));
            assets[2] = IAsset(tokenTestSuite.addressOf(Tokens.USDT));

            uint256[] memory maxAmountsIn = new uint256[](3);

            maxAmountsIn[0] = DAI_EXCHANGE_AMOUNT;
            maxAmountsIn[1] = 0;
            maxAmountsIn[2] = DAI_EXCHANGE_AMOUNT;

            JoinPoolRequest memory request;

            {
                bytes memory userData =
                    abi.encode(JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, DAI_EXCHANGE_AMOUNT);

                request = JoinPoolRequest({
                    assets: assets,
                    maxAmountsIn: maxAmountsIn,
                    userData: userData,
                    fromInternalBalance: true
                });
            }

            bytes memory passedCallData =
                abi.encodeWithSelector(IBalancerV2Vault.joinPool.selector, POOL_ID_1, USER, USER, request);

            vm.expectRevert(PoolIDNotSupportedException.selector);
            executeOneLineMulticall(creditAccount, address(adapter), passedCallData);
        }

        {
            bytes memory passedCallData = abi.encodeWithSelector(
                IBalancerV2VaultAdapter.joinPoolSingleAsset.selector,
                POOL_ID_1,
                tokenTestSuite.addressOf(Tokens.DAI),
                DAI_EXCHANGE_AMOUNT,
                DAI_EXCHANGE_AMOUNT / 2
            );

            vm.expectRevert(PoolIDNotSupportedException.selector);
            executeOneLineMulticall(creditAccount, address(adapter), passedCallData);
        }

        {
            bytes memory passedCallData = abi.encodeWithSelector(
                IBalancerV2VaultAdapter.joinPoolSingleAssetAll.selector,
                POOL_ID_1,
                tokenTestSuite.addressOf(Tokens.DAI),
                RAY / 2
            );

            vm.expectRevert(PoolIDNotSupportedException.selector);
            executeOneLineMulticall(creditAccount, address(adapter), passedCallData);
        }
    }
}
