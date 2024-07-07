// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {PhantomTokenType} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";

interface IPhantomToken {
    function _gearboxPhantomTokenType() external view returns (PhantomTokenType);

    function getWithdrawalMultiCall(address creditAccount, uint256 amount)
        external
        returns (address tokenOut, uint256 amountOut, address targetContract, bytes memory callData);
}
