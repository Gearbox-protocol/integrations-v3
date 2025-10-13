// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {PoolKey} from "../../integrations/uniswap/IUniswapUniversalRouter.sol";

interface IUniswapV4Gateway {
    error UnexpectedETHTransferException();

    function universalRouter() external view returns (address);

    function permit2() external view returns (address);

    function weth() external view returns (address);

    function swapExactInputSingle(
        PoolKey calldata poolKey,
        bool zeroForOne,
        uint128 amountIn,
        uint128 amountOutMinimum,
        bytes calldata hookData
    ) external returns (uint256 amount);
}
