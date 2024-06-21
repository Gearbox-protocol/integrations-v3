// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";

import {IAdapter} from "../../../../interfaces/IAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {
    IBalancerV2Vault,
    SingleSwap,
    BatchSwapStep,
    JoinPoolRequest,
    ExitPoolRequest,
    FundManagement,
    SwapKind,
    JoinKind,
    ExitKind
} from "../../../../integrations/balancer/IBalancerV2Vault.sol";
import {IBalancerWeightedPool} from "../../../../integrations/balancer/IBalancerWeightedPool.sol";
import {
    IBalancerV2VaultAdapter,
    PoolStatus,
    SingleSwapDiff
} from "../../../../interfaces/balancer/IBalancerV2VaultAdapter.sol";
import {IAsset} from "../../../../integrations/balancer/IAsset.sol";
import {BalancerV2_Calls, BalancerV2_Multicaller} from "../../../multicall/balancer/BalancerV2_Calls.sol";

import {Tokens, TokenType} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
import {AddressList} from "@gearbox-protocol/core-v3/contracts/test/lib/AddressList.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES
import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

struct BalancerPoolParams {
    address poolToken;
    bytes32 poolId;
    address token0;
    address token1;
    uint256 baseUnit0;
    bool isSwapOnly;
}

contract Live_BalancerV2EquivalenceTest is LiveTestHelper {
    using BalancerV2_Calls for BalancerV2_Multicaller;
    using AddressList for address[];

    BalanceComparator comparator;

    string[9] stages = [
        "after_swap",
        "after_swapDiff",
        "after_batchSwap",
        "after_joinPool",
        "after_joinPoolSingleAsset",
        "after_joinPoolSingleAssetDiff",
        "after_exitPool",
        "after_exitPoolSingleAsset",
        "after_exitPoolSingleAssetDiff"
    ];

    string[] _stages;

    function setUp() public {
        uint256 len = stages.length;
        _stages = new string[](len);

        for (uint256 i; i < len; ++i) {
            _stages[i] = stages[i];
        }
    }

    /// HELPER

    function _getDefaultFundManagement(address creditAccount) internal pure returns (FundManagement memory) {
        return FundManagement({
            sender: creditAccount,
            fromInternalBalance: false,
            recipient: payable(creditAccount),
            toInternalBalance: false
        });
    }

    function compareSwap(
        address creditAccount,
        address balancerVaultAddress,
        BalancerPoolParams memory params,
        bool isAdapter
    ) internal {
        SingleSwap memory ss = SingleSwap({
            poolId: params.poolId,
            kind: SwapKind.GIVEN_IN,
            assetIn: IAsset(params.token0),
            assetOut: IAsset(params.token1),
            amount: params.baseUnit0,
            userData: ""
        });

        if (isAdapter) {
            BalancerV2_Multicaller vault = BalancerV2_Multicaller(balancerVaultAddress);
            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(
                    vault.swap(ss, _getDefaultFundManagement(creditAccount), 0, block.timestamp + 3600)
                )
            );
        } else {
            IBalancerV2Vault vault = IBalancerV2Vault(balancerVaultAddress);

            vault.swap(ss, _getDefaultFundManagement(creditAccount), 0, block.timestamp + 3600);
        }

        comparator.takeSnapshot("after_swap", creditAccount);
    }

    function compareSwapDiff(
        address creditAccount,
        address balancerVaultAddress,
        BalancerPoolParams memory params,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            BalancerV2_Multicaller vault = BalancerV2_Multicaller(balancerVaultAddress);

            SingleSwapDiff memory ssd = SingleSwapDiff({
                poolId: params.poolId,
                leftoverAmount: 95 * params.baseUnit0,
                assetIn: IAsset(params.token0),
                assetOut: IAsset(params.token1),
                userData: ""
            });

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(vault.swapDiff(ssd, 0, block.timestamp + 3600))
            );
        } else {
            IBalancerV2Vault vault = IBalancerV2Vault(balancerVaultAddress);

            uint256 amountToSwap = IERC20(params.token0).balanceOf(creditAccount) - 95 * params.baseUnit0;

            SingleSwap memory ss = SingleSwap({
                poolId: params.poolId,
                kind: SwapKind.GIVEN_IN,
                assetIn: IAsset(params.token0),
                assetOut: IAsset(params.token1),
                amount: amountToSwap,
                userData: ""
            });

            vault.swap(ss, _getDefaultFundManagement(creditAccount), 0, block.timestamp + 3600);
        }

        comparator.takeSnapshot("after_swapDiff", creditAccount);
    }

    function compareBatchSwap(
        address creditAccount,
        address balancerVaultAddress,
        BalancerPoolParams memory params,
        bool isAdapter
    ) internal {
        bytes memory callData;

        {
            IAsset[] memory assets = new IAsset[](2);
            assets[0] = IAsset(params.token0);
            assets[1] = IAsset(params.token1);

            BatchSwapStep[] memory swaps = new BatchSwapStep[](1);

            int256[] memory limits = new int256[](2);

            limits[0] = type(int256).max;
            limits[1] = 0;

            swaps[0] = BatchSwapStep({
                poolId: params.poolId,
                assetInIndex: 0,
                assetOutIndex: 1,
                amount: params.baseUnit0,
                userData: ""
            });

            callData = abi.encodeCall(
                IBalancerV2Vault.batchSwap,
                (
                    SwapKind.GIVEN_IN,
                    swaps,
                    assets,
                    _getDefaultFundManagement(creditAccount),
                    limits,
                    block.timestamp + 3600
                )
            );
        }

        if (isAdapter) {
            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(MultiCall({target: balancerVaultAddress, callData: callData}))
            );
        } else {
            address(balancerVaultAddress).call(callData);
        }

        comparator.takeSnapshot("after_batchSwap", creditAccount);
    }

    function compareJoinPool(
        address creditAccount,
        address balancerVaultAddress,
        BalancerPoolParams memory params,
        bool isAdapter
    ) internal {
        JoinPoolRequest memory request = _getJoinRequest(
            isAdapter ? IAdapter(balancerVaultAddress).targetContract() : balancerVaultAddress,
            params.poolId,
            IAsset(params.token0),
            params.baseUnit0,
            0,
            params.poolToken
        );

        if (isAdapter) {
            BalancerV2_Multicaller vault = BalancerV2_Multicaller(balancerVaultAddress);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(vault.joinPool(params.poolId, creditAccount, creditAccount, request))
            );
        } else {
            IBalancerV2Vault vault = IBalancerV2Vault(balancerVaultAddress);

            vault.joinPool(params.poolId, creditAccount, creditAccount, request);
        }

        comparator.takeSnapshot("after_joinPool", creditAccount);
    }

    function compareJoinPoolSingleAsset(
        address creditAccount,
        address balancerVaultAddress,
        BalancerPoolParams memory params,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            BalancerV2_Multicaller vault = BalancerV2_Multicaller(balancerVaultAddress);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(
                    vault.joinPoolSingleAsset(params.poolId, IAsset(params.token0), params.baseUnit0, 0)
                )
            );
        } else {
            IBalancerV2Vault vault = IBalancerV2Vault(balancerVaultAddress);

            JoinPoolRequest memory request = _getJoinRequest(
                balancerVaultAddress, params.poolId, IAsset(params.token0), params.baseUnit0, 0, params.poolToken
            );

            vault.joinPool(params.poolId, creditAccount, creditAccount, request);
        }

        comparator.takeSnapshot("after_joinPoolSingleAsset", creditAccount);
    }

    function compareJoinPoolSingleAssetDiff(
        address creditAccount,
        address balancerVaultAddress,
        BalancerPoolParams memory params,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            BalancerV2_Multicaller vault = BalancerV2_Multicaller(balancerVaultAddress);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(
                    vault.joinPoolSingleAssetDiff(params.poolId, IAsset(params.token0), 90 * params.baseUnit0, 0)
                )
            );
        } else {
            IBalancerV2Vault vault = IBalancerV2Vault(balancerVaultAddress);

            uint256 amountToSwap = IERC20(params.token0).balanceOf(creditAccount) - 90 * params.baseUnit0;

            JoinPoolRequest memory request = _getJoinRequest(
                balancerVaultAddress, params.poolId, IAsset(params.token0), amountToSwap, 0, params.poolToken
            );

            vault.joinPool(params.poolId, creditAccount, creditAccount, request);
        }

        comparator.takeSnapshot("after_joinPoolSingleAssetDiff", creditAccount);
    }

    function compareExitPool(
        address creditAccount,
        address balancerVaultAddress,
        BalancerPoolParams memory params,
        bool isAdapter
    ) internal {
        ExitPoolRequest memory request = _getExitRequest(
            isAdapter ? IAdapter(balancerVaultAddress).targetContract() : balancerVaultAddress,
            params.poolId,
            IAsset(params.token0),
            WAD,
            0,
            params.poolToken
        );

        if (isAdapter) {
            BalancerV2_Multicaller vault = BalancerV2_Multicaller(balancerVaultAddress);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(vault.exitPool(params.poolId, creditAccount, payable(creditAccount), request))
            );
        } else {
            IBalancerV2Vault vault = IBalancerV2Vault(balancerVaultAddress);

            vault.exitPool(params.poolId, creditAccount, payable(creditAccount), request);
        }

        comparator.takeSnapshot("after_exitPool", creditAccount);
    }

    function compareExitPoolSingleAsset(
        address creditAccount,
        address balancerVaultAddress,
        BalancerPoolParams memory params,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            BalancerV2_Multicaller vault = BalancerV2_Multicaller(balancerVaultAddress);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(vault.exitPoolSingleAsset(params.poolId, IAsset(params.token0), WAD, 0))
            );
        } else {
            IBalancerV2Vault vault = IBalancerV2Vault(balancerVaultAddress);

            ExitPoolRequest memory request =
                _getExitRequest(balancerVaultAddress, params.poolId, IAsset(params.token0), WAD, 0, params.poolToken);

            vault.exitPool(params.poolId, creditAccount, payable(creditAccount), request);
        }

        comparator.takeSnapshot("after_exitPoolSingleAsset", creditAccount);
    }

    function compareExitPoolSingleAssetDiff(
        address creditAccount,
        address balancerVaultAddress,
        BalancerPoolParams memory params,
        bool isAdapter
    ) internal {
        uint256 currentBalance = IERC20(params.poolToken).balanceOf(creditAccount);

        if (isAdapter) {
            BalancerV2_Multicaller vault = BalancerV2_Multicaller(balancerVaultAddress);

            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(
                    vault.exitPoolSingleAssetDiff(params.poolId, IAsset(params.token0), currentBalance / 3, 0)
                )
            );
        } else {
            IBalancerV2Vault vault = IBalancerV2Vault(balancerVaultAddress);

            uint256 amountToSwap = currentBalance - currentBalance / 3;

            ExitPoolRequest memory request = _getExitRequest(
                balancerVaultAddress, params.poolId, IAsset(params.token0), amountToSwap, 0, params.poolToken
            );

            vault.exitPool(params.poolId, creditAccount, payable(creditAccount), request);
        }

        comparator.takeSnapshot("after_exitPoolSingleAssetDiff", creditAccount);
    }

    function _getExitRequest(
        address balancerVaultAddress,
        bytes32 poolId,
        IAsset assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address bpt
    ) internal view returns (ExitPoolRequest memory request) {
        (IERC20[] memory tokens,,) = IBalancerV2Vault(balancerVaultAddress).getPoolTokens(poolId);

        uint256 len = tokens.length;

        request.assets = new IAsset[](tokens.length);
        request.minAmountsOut = new uint256[](tokens.length);
        uint256 tokenIndex = tokens.length;
        uint256 bptIndex = tokens.length;

        unchecked {
            for (uint256 i; i < len; ++i) {
                request.assets[i] = IAsset(address(tokens[i]));

                if (request.assets[i] == assetOut) {
                    request.minAmountsOut[i] = minAmountOut;
                    tokenIndex = i;
                }

                if (address(request.assets[i]) == bpt) {
                    bptIndex = i;
                }
            }
        }

        tokenIndex = tokenIndex > bptIndex ? tokenIndex - 1 : tokenIndex;

        request.userData = abi.encode(uint256(0), amountIn, tokenIndex);
    }

    function _getJoinRequest(
        address balancerVaultAddress,
        bytes32 poolId,
        IAsset assetIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address bpt
    ) internal view returns (JoinPoolRequest memory request) {
        (IERC20[] memory tokens,,) = IBalancerV2Vault(balancerVaultAddress).getPoolTokens(poolId);

        uint256 len = tokens.length;

        request.assets = new IAsset[](tokens.length);
        request.maxAmountsIn = new uint256[](tokens.length);
        uint256 bptIndex = tokens.length;

        unchecked {
            for (uint256 i; i < len; ++i) {
                request.assets[i] = IAsset(address(tokens[i]));

                if (request.assets[i] == assetIn) {
                    request.maxAmountsIn[i] = amountIn;
                }

                if (address(request.assets[i]) == bpt) {
                    bptIndex = i;
                }
            }
        }

        request.userData = abi.encode(uint256(1), _removeIndex(request.maxAmountsIn, bptIndex), minAmountOut);
    }

    /// @dev Returns copy of `array` without an element at `index`
    function _removeIndex(uint256[] memory array, uint256 index) internal pure returns (uint256[] memory res) {
        uint256 len = array.length;

        if (index >= len) {
            return array;
        }

        len = len - 1;

        res = new uint256[](len);

        for (uint256 i = 0; i < len;) {
            if (i < index) {
                res[i] = array[i];
            } else {
                res[i] = array[i + 1];
            }

            unchecked {
                ++i;
            }
        }
    }

    function compareBehavior(
        address creditAccount,
        address balancerVaultAddress,
        BalancerPoolParams memory params,
        bool isAdapter
    ) internal {
        if (isAdapter) {
            vm.startPrank(USER);
        } else {
            vm.startPrank(creditAccount);
        }

        compareSwap(creditAccount, balancerVaultAddress, params, isAdapter);

        compareSwapDiff(creditAccount, balancerVaultAddress, params, isAdapter);

        compareBatchSwap(creditAccount, balancerVaultAddress, params, isAdapter);

        if (!params.isSwapOnly) {
            compareJoinPool(creditAccount, balancerVaultAddress, params, isAdapter);

            compareJoinPoolSingleAsset(creditAccount, balancerVaultAddress, params, isAdapter);

            compareJoinPoolSingleAssetDiff(creditAccount, balancerVaultAddress, params, isAdapter);

            compareExitPool(creditAccount, balancerVaultAddress, params, isAdapter);

            compareExitPoolSingleAsset(creditAccount, balancerVaultAddress, params, isAdapter);

            compareExitPoolSingleAssetDiff(creditAccount, balancerVaultAddress, params, isAdapter);
        }

        vm.stopPrank();
    }

    function openCreditAccountWithToken0(address token, uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        tokenTestSuite.mint(token, creditAccount, amount);
    }

    function prepareComparator(address balancerVaultAdapter, bytes32 poolId) internal {
        address balancerVaultAddress = IAdapter(balancerVaultAdapter).targetContract();

        (IERC20[] memory tokens,,) = IBalancerV2Vault(balancerVaultAddress).getPoolTokens(poolId);

        address[] memory tokensToTrack = new address[](9);

        (tokensToTrack[0],) = IBalancerV2Vault(balancerVaultAddress).getPool(poolId);

        for (uint256 i = 0; i < tokens.length; ++i) {
            tokensToTrack[i + 1] = address(tokens[i]);
        }

        tokensToTrack = tokensToTrack.trim();

        Tokens[] memory _tokensToTrack = new Tokens[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    function _getSwappableTokens(address balancerVaultAdapter, bytes32 poolId)
        internal
        view
        returns (address token0, address token1, uint256 baseUnit0)
    {
        (IERC20[] memory tokens,,) =
            IBalancerV2Vault(IAdapter(balancerVaultAdapter).targetContract()).getPoolTokens(poolId);

        (address pool,) = IBalancerV2Vault(IAdapter(balancerVaultAdapter).targetContract()).getPool(poolId);

        for (uint256 i = 0; i < tokens.length; ++i) {
            if (token0 == address(0)) {
                if (address(tokens[i]) != pool) {
                    try creditManager.getTokenMaskOrRevert(address(tokens[i])) returns (uint256) {
                        token0 = address(tokens[i]);
                        baseUnit0 = 10 ** IERC20Metadata(address(token0)).decimals();
                    } catch {}
                }
            } else if (token1 == address(0)) {
                if (address(tokens[i]) != pool) {
                    try creditManager.getTokenMaskOrRevert(address(tokens[i])) returns (uint256) {
                        token1 = address(tokens[i]);
                        break;
                    } catch {}
                }
            }
        }
    }

    /// @dev [L-BALET-1]: Balancer adapters and original contracts work identically
    function test_live_BALET_01_Balancer_adapters_and_original_contracts_are_equivalent() public attachOrLiveTest {
        address balancerVaultAdapter = getAdapter(address(creditManager), Contracts.BALANCER_VAULT);

        if (balancerVaultAdapter == address(0)) return;

        for (uint256 i = 0; i < uint256(type(Tokens).max); ++i) {
            if (tokenTestSuite.tokenTypes(Tokens(i)) != TokenType.BALANCER_LP_TOKEN) continue;

            address pool = tokenTestSuite.addressOf(Tokens(i));
            bytes32 poolId = IBalancerWeightedPool(pool).getPoolId();

            if (IBalancerV2VaultAdapter(balancerVaultAdapter).poolStatus(poolId) == PoolStatus.NOT_ALLOWED) continue;

            uint256 snapshot0 = vm.snapshot();

            BalancerPoolParams memory params = BalancerPoolParams({
                poolToken: pool,
                poolId: poolId,
                token0: address(0),
                token1: address(0),
                baseUnit0: 0,
                isSwapOnly: IBalancerV2VaultAdapter(balancerVaultAdapter).poolStatus(poolId) == PoolStatus.SWAP_ONLY
            });

            (params.token0, params.token1, params.baseUnit0) = _getSwappableTokens(balancerVaultAdapter, poolId);

            address creditAccount = openCreditAccountWithToken0(params.token0, 100 * params.baseUnit0);

            tokenTestSuite.approve(params.token0, creditAccount, IAdapter(balancerVaultAdapter).targetContract());

            tokenTestSuite.approve(params.poolToken, creditAccount, IAdapter(balancerVaultAdapter).targetContract(), 0);

            tokenTestSuite.approve(params.poolToken, creditAccount, IAdapter(balancerVaultAdapter).targetContract());

            uint256 snapshot1 = vm.snapshot();

            prepareComparator(balancerVaultAdapter, params.poolId);

            compareBehavior(creditAccount, IAdapter(balancerVaultAdapter).targetContract(), params, false);

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot1);

            prepareComparator(balancerVaultAdapter, params.poolId);

            compareBehavior(creditAccount, balancerVaultAdapter, params, true);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots, 0);

            vm.revertTo(snapshot0);
        }
    }
}
