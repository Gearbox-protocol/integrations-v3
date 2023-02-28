// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.17;

import {
    IBalancerV2Vault,
    PoolSpecialization,
    SingleSwap,
    BatchSwapStep,
    FundManagement,
    SwapKind,
    JoinPoolRequest,
    ExitPoolRequest,
    JoinKind,
    ExitKind
} from "../../../integrations/balancer/IBalancerV2Vault.sol";
import {IAsset} from "../../../integrations/balancer/IAsset.sol";
import {BPTMock} from "./BPTMock.sol";
import {BPTStableMock} from "./BPTStableMock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

struct PoolData {
    address pool;
    address[] assets;
    uint256[] balances;
    mapping(address => mapping(address => uint256)) ratesRAY;
    mapping(address => uint256) depositRatesRAY;
    mapping(address => uint256) withdrawalRatesRAY;
    PoolSpecialization specialization;
    uint24 fee;
}

contract BalancerVaultMock is IBalancerV2Vault {
    mapping(bytes32 => PoolData) poolData;

    function addPool(
        bytes32 poolId,
        address[] memory assets,
        uint256[] memory weights,
        PoolSpecialization specialization,
        uint24 fee
    ) external {
        address pool = address(new BPTMock("Balancer Pool Token", "BPT", 18, weights, poolId));

        poolData[poolId].pool = pool;
        poolData[poolId].assets = assets;
        poolData[poolId].specialization = specialization;
        poolData[poolId].fee = fee;
    }

    function addStablePool(bytes32 poolId, address[] memory assets, uint24 fee) external {
        address pool = address(new BPTStableMock("Balancer Stable Pool Token", "BSPT", 18, poolId));

        poolData[poolId].pool = pool;
        poolData[poolId].assets = assets;
        poolData[poolId].specialization = PoolSpecialization.MINIMAL_SWAP_INFO;
        poolData[poolId].fee = fee;
    }

    function setRate(bytes32 poolId, address asset0, address asset1, uint256 rateRAY) external {
        poolData[poolId].ratesRAY[asset0][asset1] = rateRAY;
        poolData[poolId].ratesRAY[asset1][asset0] = (RAY * RAY) / rateRAY;
    }

    function setDepositRate(bytes32 poolId, address asset, uint256 rateRAY) external {
        poolData[poolId].depositRatesRAY[asset] = rateRAY;
    }

    function setWithdrawalRate(bytes32 poolId, address asset, uint256 rateRAY) external {
        poolData[poolId].withdrawalRatesRAY[asset] = rateRAY;
    }

    function setAssetBalances(bytes32 poolId, uint256[] memory balances) external {
        require(poolData[poolId].assets.length == balances.length);
        poolData[poolId].balances = balances;
    }

    function mintBPT(bytes32 poolId, address to, uint256 amount) external {
        BPTMock(poolData[poolId].pool).mint(to, amount);
    }

    function swap(SingleSwap memory singleSwap, FundManagement memory funds, uint256 limit, uint256 deadline)
        external
        returns (uint256 amountCalculated)
    {
        require(
            !funds.fromInternalBalance && !funds.toInternalBalance && funds.sender == funds.recipient
                && funds.sender == msg.sender,
            "BalancerVault: Unsupported funds struct"
        );

        require(block.timestamp <= deadline, "BalancerVault: Deadline passed");

        require(poolData[singleSwap.poolId].pool != address(0), "BalancerVault: Unknown pool");

        uint256 rate = poolData[singleSwap.poolId].ratesRAY[address(singleSwap.assetIn)][address(singleSwap.assetOut)];

        require(rate != 0, "BalancerVault: Rate not set");

        amountCalculated =
            singleSwap.kind == SwapKind.GIVEN_IN ? (singleSwap.amount * rate) / RAY : (singleSwap.amount * RAY) / rate;

        if (singleSwap.kind == SwapKind.GIVEN_IN) {
            amountCalculated =
                (singleSwap.amount * rate * (10000 - uint256(poolData[singleSwap.poolId].fee))) / (RAY * 10000);

            require(amountCalculated >= limit, "BalancerVault: GIVEN_IN output below limit");

            IERC20(address(singleSwap.assetIn)).transferFrom(funds.sender, address(this), singleSwap.amount);
            IERC20(address(singleSwap.assetOut)).transfer(funds.recipient, amountCalculated);
        } else {
            amountCalculated =
                (singleSwap.amount * RAY * 10000) / (rate * (10000 - uint256(poolData[singleSwap.poolId].fee)));

            require(amountCalculated <= limit, "BalancerVault: GIVEN_OUT input above limit");

            IERC20(address(singleSwap.assetIn)).transferFrom(funds.sender, address(this), amountCalculated);
            IERC20(address(singleSwap.assetOut)).transfer(funds.recipient, singleSwap.amount);
        }
    }

    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory funds,
        int256[] memory limits,
        uint256 deadline
    ) external returns (int256[] memory assetDeltas) {
        require(
            !funds.fromInternalBalance && !funds.toInternalBalance && funds.sender == funds.recipient
                && funds.sender == msg.sender,
            "BalancerVault: Unsupported funds struct"
        );

        require(block.timestamp <= deadline, "BalancerVault: Deadline passed");

        assetDeltas = queryBatchSwap(kind, swaps, assets, funds);

        for (uint256 i = 0; i < assetDeltas.length; ++i) {
            require(assetDeltas[i] <= limits[i], "BalancerVault: BatchSwap output outside limits");

            if (assetDeltas[i] < 0) {
                IERC20(address(assets[i])).transfer(funds.recipient, uint256(-assetDeltas[i]));
            } else if (assetDeltas[i] > 0) {
                IERC20(address(assets[i])).transferFrom(funds.sender, address(this), uint256(assetDeltas[i]));
            }
        }
    }

    function queryBatchSwap(SwapKind kind, BatchSwapStep[] memory swaps, IAsset[] memory assets, FundManagement memory)
        public
        view
        returns (int256[] memory assetDeltas)
    {
        assetDeltas = new int256[](assets.length);

        if (kind == SwapKind.GIVEN_IN) {
            for (uint256 i = 0; i < swaps.length; ++i) {
                require(poolData[swaps[i].poolId].pool != address(0), "BalancerVault: Unknown pool");

                address assetIn = address(assets[swaps[i].assetInIndex]);
                address assetOut = address(assets[swaps[i].assetOutIndex]);

                uint256 amountIn;

                if (swaps[i].amount > 0) {
                    amountIn = swaps[i].amount;
                    assetDeltas[swaps[i].assetInIndex] += int256(swaps[i].amount);
                } else {
                    amountIn = uint256(-assetDeltas[swaps[i].assetInIndex]);
                    assetDeltas[swaps[i].assetInIndex] = 0;
                }

                uint256 rate = poolData[swaps[i].poolId].ratesRAY[assetIn][assetOut];

                require(rate != 0, "BalancerVault: Rate not set");

                assetDeltas[swaps[i].assetOutIndex] -=
                    int256((amountIn * rate * (10000 - uint256(poolData[swaps[i].poolId].fee))) / (RAY * 10000));
            }
        } else {
            for (uint256 i = swaps.length; i >= 0; --i) {
                require(poolData[swaps[i].poolId].pool != address(0), "BalancerVault: Unknown pool");

                address assetIn = address(assets[swaps[i].assetInIndex]);
                address assetOut = address(assets[swaps[i].assetOutIndex]);

                uint256 amountOut;

                if (swaps[i].amount > 0) {
                    amountOut = swaps[i].amount;
                    assetDeltas[swaps[i].assetOutIndex] -= int256(swaps[i].amount);
                } else {
                    amountOut = uint256(assetDeltas[swaps[i].assetOutIndex]);
                    assetDeltas[swaps[i].assetOutIndex] = 0;
                }

                uint256 rate = poolData[swaps[i].poolId].ratesRAY[assetIn][assetOut];

                require(rate != 0, "BalancerVault: Rate not set");

                assetDeltas[swaps[i].assetInIndex] +=
                    int256((amountOut * RAY * 10000) / (rate * (10000 - uint256(poolData[swaps[i].poolId].fee))));
            }
        }
    }

    function joinPool(bytes32 poolId, address sender, address recipient, JoinPoolRequest memory request) external {
        require(sender == recipient && sender == msg.sender, "BalancerVault: Unsupported sender or recipient");

        require(poolData[poolId].pool != address(0), "BalancerVault: Unknown pool");

        JoinKind kind = _joinKind(request.userData);

        if (kind == JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT) {
            (uint256[] memory amountsIn, uint256 minBPTAmountOut) = _exactTokensInForBPTOut(request.userData);

            uint256 bptOut;

            for (uint256 i = 0; i < request.assets.length; ++i) {
                require(amountsIn[i] <= request.maxAmountsIn[i], "BalancerVault: Asset deposit exceeds limit");

                IERC20(address(request.assets[i])).transferFrom(sender, address(this), amountsIn[i]);

                poolData[poolId].balances[i] += amountsIn[i];

                uint256 rate = poolData[poolId].depositRatesRAY[address(request.assets[i])];

                require(rate != 0, "BalancerVault: Deposit rate not set");

                bptOut += (amountsIn[i] * poolData[poolId].depositRatesRAY[address(request.assets[i])]) / RAY;
            }

            require(bptOut >= minBPTAmountOut, "BalancerVault: Insufficient BPT out amount");

            BPTMock(poolData[poolId].pool).mint(recipient, bptOut);
        } else if (kind == JoinKind.TOKEN_IN_FOR_EXACT_BPT_OUT) {
            (uint256 bptAmountOut, uint256 tokenIndex) = _tokenInForExactBPTOut(request.userData);

            address asset = address(request.assets[tokenIndex]);

            uint256 rate = poolData[poolId].depositRatesRAY[asset];

            require(rate != 0, "BalancerVault: Deposit rate not set");

            uint256 amountIn = (bptAmountOut * RAY) / rate;

            require(amountIn <= request.maxAmountsIn[tokenIndex], "BalancerVault: Asset deposit exceeds limit");

            IERC20(address(request.assets[tokenIndex])).transferFrom(sender, address(this), amountIn);

            poolData[poolId].balances[tokenIndex] += amountIn;

            BPTMock(poolData[poolId].pool).mint(recipient, bptAmountOut);
        } else if (kind == JoinKind.ALL_TOKENS_IN_FOR_EXACT_BPT_OUT) {
            uint256 bptAmountOut = _allTokensInForExactBptOut(request.userData);

            uint256 nAssets = request.assets.length;

            for (uint256 i = 0; i < nAssets; ++i) {
                address asset = address(request.assets[i]);

                uint256 rate = poolData[poolId].depositRatesRAY[asset];

                require(rate != 0, "BalancerVault: Deposit rate not set");

                uint256 amountIn = (bptAmountOut * RAY) / (rate * nAssets);

                require(amountIn <= request.maxAmountsIn[i], "BalancerVault: Asset deposit exceeds limit");

                IERC20(address(request.assets[i])).transferFrom(sender, address(this), amountIn);

                poolData[poolId].balances[i] += amountIn;
            }

            BPTMock(poolData[poolId].pool).mint(recipient, bptAmountOut);
        }
    }

    function _joinKind(bytes memory userData) internal pure returns (JoinKind) {
        return abi.decode(userData, (JoinKind));
    }

    function _exactTokensInForBPTOut(bytes memory userData)
        internal
        pure
        returns (uint256[] memory amountsIn, uint256 minBPTAmountOut)
    {
        (, amountsIn, minBPTAmountOut) = abi.decode(userData, (JoinKind, uint256[], uint256));
    }

    function _tokenInForExactBPTOut(bytes memory userData)
        internal
        pure
        returns (uint256 bptAmountOut, uint256 tokenIndex)
    {
        (, bptAmountOut, tokenIndex) = abi.decode(userData, (JoinKind, uint256, uint256));
    }

    function _allTokensInForExactBptOut(bytes memory userData) internal pure returns (uint256 bptAmountOut) {
        (, bptAmountOut) = abi.decode(userData, (JoinKind, uint256));
    }

    function exitPool(bytes32 poolId, address sender, address payable recipient, ExitPoolRequest memory request)
        external
    {
        require(sender == recipient && sender == msg.sender, "BalancerVault: Unsupported sender or recipient");

        require(poolData[poolId].pool != address(0), "BalancerVault: Unknown pool");

        ExitKind kind = _exitKind(request.userData);

        if (kind == ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT) {
            (uint256 bptAmountIn, uint256 tokenIndex) = _exactBptInForTokenOut(request.userData);

            address asset = address(request.assets[tokenIndex]);

            uint256 rate = poolData[poolId].withdrawalRatesRAY[asset];

            require(rate != 0, "BalancerVault: Withdrawal rate not set");

            uint256 amountOut = (bptAmountIn * rate) / RAY;

            require(amountOut >= request.minAmountsOut[tokenIndex], "BalancerVault: Insufficient asset amount out");

            BPTMock(poolData[poolId].pool).burn(sender, bptAmountIn);

            IERC20(asset).transfer(recipient, amountOut);

            poolData[poolId].balances[tokenIndex] -= amountOut;
        } else if (kind == ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT) {
            uint256 bptAmountIn = _exactBptInForTokensOut(request.userData);

            uint256 nAssets = request.assets.length;

            for (uint256 i = 0; i < nAssets; ++i) {
                address asset = address(request.assets[i]);

                uint256 rate = poolData[poolId].withdrawalRatesRAY[asset];

                require(rate != 0, "BalancerVault: Withdrawal rate not set");

                uint256 amountOut = (bptAmountIn * rate) / (nAssets * RAY);

                require(amountOut >= request.minAmountsOut[i], "BalancerVault: Insufficient asset amount out");

                IERC20(asset).transfer(recipient, amountOut);

                poolData[poolId].balances[i] -= amountOut;
            }

            BPTMock(poolData[poolId].pool).burn(sender, bptAmountIn);
        } else if (kind == ExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT) {
            (uint256[] memory amountsOut, uint256 maxBPTAmountIn) = _bptInForExactTokensOut(request.userData);

            uint256 nAssets = request.assets.length;

            uint256 bptIn = 0;

            for (uint256 i = 0; i < nAssets; ++i) {
                require(amountsOut[i] >= request.minAmountsOut[i], "BalancerVault: Insufficient asset amount out");

                address asset = address(request.assets[i]);

                uint256 rate = poolData[poolId].withdrawalRatesRAY[asset];

                require(rate != 0, "BalancerVault: Withdrawal rate not set");

                bptIn += (amountsOut[i] * RAY) / rate;

                IERC20(asset).transfer(recipient, amountsOut[i]);

                poolData[poolId].balances[i] -= amountsOut[i];
            }

            require(bptIn <= maxBPTAmountIn, "BalancerVault: BPT amount burned larger than limit");

            BPTMock(poolData[poolId].pool).burn(sender, bptIn);
        }
    }

    function _exitKind(bytes memory userData) internal pure returns (ExitKind) {
        return abi.decode(userData, (ExitKind));
    }

    function _exactBptInForTokenOut(bytes memory userData)
        internal
        pure
        returns (uint256 bptAmountIn, uint256 tokenIndex)
    {
        (, bptAmountIn, tokenIndex) = abi.decode(userData, (ExitKind, uint256, uint256));
    }

    function _exactBptInForTokensOut(bytes memory userData) internal pure returns (uint256 bptAmountIn) {
        (, bptAmountIn) = abi.decode(userData, (ExitKind, uint256));
    }

    function _bptInForExactTokensOut(bytes memory userData)
        internal
        pure
        returns (uint256[] memory amountsOut, uint256 maxBPTAmountIn)
    {
        (, amountsOut, maxBPTAmountIn) = abi.decode(userData, (ExitKind, uint256[], uint256));
    }

    function getPool(bytes32 poolId) external view returns (address, PoolSpecialization) {
        require(poolData[poolId].pool != address(0), "BalancerVault: Unknown pool");

        return (poolData[poolId].pool, poolData[poolId].specialization);
    }

    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock)
    {
        require(poolData[poolId].pool != address(0), "BalancerVault: Unknown pool");

        uint256 len = poolData[poolId].assets.length;

        tokens = new IERC20[](len);
        balances = new uint256[](len);
        lastChangeBlock = block.timestamp;

        for (uint256 i = 0; i < len; ++i) {
            tokens[i] = IERC20(poolData[poolId].assets[i]);
            balances[i] = poolData[poolId].balances[i];
        }
    }

    function getPoolTokenInfo(bytes32, IERC20)
        external
        view
        returns (uint256 cash, uint256 managed, uint256 lastChangeBlock, address assetManager)
    {
        return (0, 0, block.timestamp, address(this));
    }
}
