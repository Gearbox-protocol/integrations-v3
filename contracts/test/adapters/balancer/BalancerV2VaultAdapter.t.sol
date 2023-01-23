// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { ICreditManagerV2Exceptions } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";

import { IBalancerV2Vault, PoolSpecialization, SingleSwap, FundManagement, SwapKind } from "../../../integrations/balancer/IBalancerV2Vault.sol";
import { IBalancerV2VaultAdapter, SingleSwapAll } from "../../../interfaces/balancer/IBalancerV2VaultAdapter.sol";
import { IAsset } from "../../../integrations/balancer/IAsset.sol";
import { BalancerV2VaultAdapter } from "../../../adapters/balancer/BalancerV2Vault.sol";
import { BPTStablePriceFeed } from "../../../oracles/balancer/BPTStablePriceFeed.sol";
import { BPTWeightedPriceFeed } from "../../../oracles/balancer/BPTWeightedPriceFeed.sol";
import { IBalancerV2VaultAdapter } from "../../../interfaces/balancer/IBalancerV2VaultAdapter.sol";
import { BalancerVaultMock } from "../../mocks/integrations/BalancerVaultMock.sol";

import { Tokens } from "../../suites/TokensTestSuite.sol";

// TEST
import "../../lib/constants.sol";
import { AdapterTestHelper } from "../AdapterTestHelper.sol";

bytes32 constant POOL_ID_1 = bytes32(uint256(1));
bytes32 constant POOL_ID_2 = bytes32(uint256(2));

/// @title BalancerVaultTest
/// @notice Designed for unit test purposes only
contract BalancerV2VaultAdapterTest is AdapterTestHelper {
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
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.DAI),
            tokenTestSuite.addressOf(Tokens.USDC),
            RAY
        );

        balancerMock.setRate(
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.USDT),
            tokenTestSuite.addressOf(Tokens.DAI),
            (99 * RAY) / 100
        );

        balancerMock.setRate(
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.USDT),
            tokenTestSuite.addressOf(Tokens.USDC),
            (99 * RAY) / 100
        );

        balancerMock.setDepositRate(
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.DAI),
            RAY
        );

        balancerMock.setDepositRate(
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.USDC),
            RAY
        );

        balancerMock.setDepositRate(
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.USDT),
            RAY
        );

        balancerMock.setWithdrawalRate(
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.DAI),
            RAY
        );

        balancerMock.setWithdrawalRate(
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.USDC),
            RAY
        );

        balancerMock.setWithdrawalRate(
            POOL_ID_1,
            tokenTestSuite.addressOf(Tokens.USDT),
            RAY
        );

        tokenTestSuite.mint(Tokens.DAI, address(balancerMock), RAY);

        tokenTestSuite.mint(Tokens.USDC, address(balancerMock), RAY);

        tokenTestSuite.mint(Tokens.USDT, address(balancerMock), RAY);

        (address bpt, ) = balancerMock.getPool(POOL_ID_1);

        address[] memory priceFeeds = new address[](3);
        priceFeeds[0] = cft.priceOracle().priceFeeds(assets[0]);
        priceFeeds[1] = cft.priceOracle().priceFeeds(assets[1]);
        priceFeeds[2] = cft.priceOracle().priceFeeds(assets[2]);

        address bptPf = address(
            new BPTStablePriceFeed(
                address(cft.addressProvider()),
                bpt,
                3,
                priceFeeds
            )
        );

        evm.startPrank(CONFIGURATOR);

        cft.priceOracle().addPriceFeed(bpt, bptPf);
        creditConfigurator.addCollateralToken(bpt, 9000);

        evm.stopPrank();

        assets = new address[](2);

        assets[0] = tokenTestSuite.addressOf(Tokens.DAI);
        assets[1] = tokenTestSuite.addressOf(Tokens.WETH);

        uint256[] memory weights = new uint256[](2);

        weights[0] = WAD / 2;
        weights[1] = WAD / 2;

        balancerMock.addPool(
            POOL_ID_2,
            assets,
            weights,
            PoolSpecialization.MINIMAL_SWAP_INFO,
            50
        );

        balancerMock.setRate(
            POOL_ID_2,
            tokenTestSuite.addressOf(Tokens.DAI),
            tokenTestSuite.addressOf(Tokens.WETH),
            RAY / DAI_WETH_RATE
        );

        balancerMock.setDepositRate(
            POOL_ID_2,
            tokenTestSuite.addressOf(Tokens.DAI),
            RAY
        );

        balancerMock.setWithdrawalRate(
            POOL_ID_2,
            tokenTestSuite.addressOf(Tokens.DAI),
            RAY
        );

        balancerMock.setDepositRate(
            POOL_ID_2,
            tokenTestSuite.addressOf(Tokens.WETH),
            RAY * DAI_WETH_RATE
        );

        balancerMock.setWithdrawalRate(
            POOL_ID_2,
            tokenTestSuite.addressOf(Tokens.WETH),
            RAY / DAI_WETH_RATE
        );

        tokenTestSuite.mint(Tokens.DAI, address(balancerMock), RAY);

        tokenTestSuite.mint(Tokens.WETH, address(balancerMock), RAY);

        uint256[] memory balances = new uint256[](2);

        balances[0] = 10000000 * WAD;
        balances[1] = balances[0] / DAI_WETH_RATE;

        balancerMock.setAssetBalances(POOL_ID_2, balances);

        balancerMock.mintBPT(POOL_ID_2, FRIEND2, 20000000 * WAD);

        (bpt, ) = balancerMock.getPool(POOL_ID_2);

        priceFeeds = new address[](2);
        priceFeeds[0] = cft.priceOracle().priceFeeds(assets[0]);
        priceFeeds[1] = cft.priceOracle().priceFeeds(assets[1]);

        bptPf = address(
            new BPTWeightedPriceFeed(
                address(cft.addressProvider()),
                address(balancerMock),
                bpt,
                priceFeeds
            )
        );

        evm.startPrank(CONFIGURATOR);

        cft.priceOracle().addPriceFeed(bpt, bptPf);
        creditConfigurator.addCollateralToken(bpt, 9000);

        evm.stopPrank();

        adapter = new BalancerV2VaultAdapter(
            address(creditManager),
            address(balancerMock)
        );

        evm.prank(CONFIGURATOR);
        creditConfigurator.allowContract(
            address(balancerMock),
            address(adapter)
        );

        evm.label(address(adapter), "ADAPTER");
        evm.label(address(balancerMock), "BALANCER_MOCK");

        deadline = _getUniswapDeadline();
    }

    function _standardFundManagement(address creditAccount)
        internal
        returns (FundManagement memory)
    {
        return
            FundManagement({
                sender: creditAccount,
                fromInternalBalance: false,
                recipient: payable(creditAccount),
                toInternalBalance: false
            });
    }

    ///
    ///
    ///  TESTS
    ///
    ///

    /// @dev [ABV2-1]: swap works as expected
    function test_ABV2_01_swap_works_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            (
                address creditAccount,
                uint256 initialDAIBalance
            ) = _openTestCreditAccount();

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

            expectAllowance(
                Tokens.DAI,
                creditAccount,
                address(balancerMock),
                0
            );

            expectAllowance(
                Tokens.WETH,
                creditAccount,
                address(balancerMock),
                0
            );

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

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(balancerMock),
                    USER,
                    expectedCallData,
                    tokenTestSuite.addressOf(Tokens.DAI),
                    tokenTestSuite.addressOf(Tokens.WETH),
                    true
                );

                executeOneLineMulticall(address(adapter), passedCallData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(balancerMock),
                    USER,
                    expectedCallData,
                    tokenTestSuite.addressOf(Tokens.DAI),
                    tokenTestSuite.addressOf(Tokens.WETH),
                    true
                );

                evm.prank(USER);
                adapter.swap(
                    singleSwapData,
                    fundManagement,
                    DAI_EXCHANGE_AMOUNT / (DAI_WETH_RATE * 2),
                    deadline
                );
            }

            expectBalance(
                Tokens.DAI,
                creditAccount,
                initialDAIBalance - DAI_EXCHANGE_AMOUNT
            );

            expectBalance(
                Tokens.WETH,
                creditAccount,
                ((DAI_EXCHANGE_AMOUNT / DAI_WETH_RATE) * 9950) / 10000
            );

            expectAllowance(
                Tokens.DAI,
                creditAccount,
                address(balancerMock),
                1
            );

            expectTokenIsEnabled(Tokens.WETH, true);
        }
    }

    function test_ABV2_02_swapAll_works_as_expected() public {
        for (uint256 m = 0; m < 2; m++) {
            bool multicall = m != 0;

            setUp();
            (
                address creditAccount,
                uint256 initialDAIBalance
            ) = _openTestCreditAccount();

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
                IBalancerV2VaultAdapter.swapAll.selector,
                singleSwapAllData,
                RAY / (DAI_WETH_RATE * 2),
                deadline
            );

            expectAllowance(
                Tokens.DAI,
                creditAccount,
                address(balancerMock),
                0
            );

            expectAllowance(
                Tokens.WETH,
                creditAccount,
                address(balancerMock),
                0
            );

            if (multicall) {
                expectMulticallStackCalls(
                    address(adapter),
                    address(balancerMock),
                    USER,
                    expectedCallData,
                    tokenTestSuite.addressOf(Tokens.DAI),
                    tokenTestSuite.addressOf(Tokens.WETH),
                    true
                );

                executeOneLineMulticall(address(adapter), passedCallData);
            } else {
                expectFastCheckStackCalls(
                    address(adapter),
                    address(balancerMock),
                    USER,
                    expectedCallData,
                    tokenTestSuite.addressOf(Tokens.DAI),
                    tokenTestSuite.addressOf(Tokens.WETH),
                    true
                );

                uint256 gas = gasleft();
                evm.prank(USER);
                adapter.swapAll(
                    singleSwapAllData,
                    RAY / (DAI_WETH_RATE * 2),
                    deadline
                );
            }

            expectBalance(Tokens.DAI, creditAccount, 1);

            expectBalance(
                Tokens.WETH,
                creditAccount,
                (((initialDAIBalance - 1) / DAI_WETH_RATE) * 9950) / 10000
            );

            expectAllowance(
                Tokens.DAI,
                creditAccount,
                address(balancerMock),
                1
            );

            expectTokenIsEnabled(Tokens.DAI, false);
            expectTokenIsEnabled(Tokens.WETH, true);
        }
    }
}
