// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {AbstractAdapter} from "../../../adapters/AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

contract AbstractAdapterHarness is AbstractAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.ABSTRACT;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    constructor(address _creditManager, address _targetContract) AbstractAdapter(_creditManager, _targetContract) {}

    function revertIfCallerNotCreditFacade() external view {
        _revertIfCallerNotCreditFacade();
    }

    function creditAccount() external view returns (address) {
        return _creditAccount();
    }

    function getMaskOrRevert(address token) external view returns (uint256 tokenMask) {
        return _getMaskOrRevert(token);
    }

    function approveToken(address token, uint256 amount) external {
        _approveToken(token, amount);
    }

    function execute(bytes memory callData) external returns (bytes memory result) {
        result = _execute(callData);
    }

    function executeSwapNoApprove(address tokenIn, address tokenOut, bytes memory callData, bool disableTokenIn)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable, bytes memory result)
    {
        return _executeSwapNoApprove(tokenIn, tokenOut, callData, disableTokenIn);
    }

    function executeSwapSafeApprove(address tokenIn, address tokenOut, bytes memory callData, bool disableTokenIn)
        external
        returns (uint256 tokensToEnable, uint256 tokensToDisable, bytes memory result)
    {
        return _executeSwapSafeApprove(tokenIn, tokenOut, callData, disableTokenIn);
    }
}
