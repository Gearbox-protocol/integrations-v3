// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IPoolV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPoolV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {ILidoWithdrawalQueueGateway} from "../../interfaces/lido/ILidoWithdrawalQueueGateway.sol";
import {ILidoWithdrawalQueueAdapter} from "../../interfaces/lido/ILidoWithdrawalQueueAdapter.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Lido withdrawal queue adapter
/// @notice Implements logic for interacting with the Lido withdrawal queue through the gateway
contract LidoWithdrawalQueueAdapter is AbstractAdapter, ILidoWithdrawalQueueAdapter {
    bytes32 public constant override contractType = "ADAPTER::LIDO_WITHDRAWAL_QUEUE";
    uint256 public constant override version = 3_10;

    /// @notice stETH token
    address public immutable override stETH;

    /// @notice wstETH token
    address public immutable override wstETH;

    /// @notice WETH token
    address public immutable override weth;

    /// @notice Lido withdrawal phantom token
    address public immutable override lidoWithdrawalPhantomToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _withdrawalQueueGateway Lido withdrawal queue gateway address
    /// @param _lidoWithdrawalPhantomToken Lido withdrawal phantom token address
    constructor(address _creditManager, address _withdrawalQueueGateway, address _lidoWithdrawalPhantomToken)
        AbstractAdapter(_creditManager, _withdrawalQueueGateway)
    {
        stETH = ILidoWithdrawalQueueGateway(_withdrawalQueueGateway).steth();
        weth = ILidoWithdrawalQueueGateway(_withdrawalQueueGateway).weth();
        wstETH = ILidoWithdrawalQueueGateway(_withdrawalQueueGateway).wsteth();

        lidoWithdrawalPhantomToken = _lidoWithdrawalPhantomToken;

        _getMaskOrRevert(stETH);
        _getMaskOrRevert(weth);
        _getMaskOrRevert(wstETH);
        _getMaskOrRevert(lidoWithdrawalPhantomToken);
    }

    /// @notice Requests withdrawals from the Lido withdrawal queue
    /// @param amounts Amounts of stETH to withdraw
    function requestWithdrawals(uint256[] calldata amounts) external override creditFacadeOnly returns (bool) {
        _executeSwapSafeApprove(stETH, abi.encodeCall(ILidoWithdrawalQueueGateway.requestWithdrawals, (amounts)));
        return true;
    }

    /// @notice Requests wstETH withdrawals from the Lido withdrawal queue
    function requestWithdrawalsWstETH(uint256[] calldata amounts) external override creditFacadeOnly returns (bool) {
        _executeSwapSafeApprove(wstETH, abi.encodeCall(ILidoWithdrawalQueueGateway.requestWithdrawalsWstETH, (amounts)));
        return true;
    }

    /// @notice Claims the request WETH amount from the withdrawal queue gateway
    function claimWithdrawals(uint256 amount) external override creditFacadeOnly returns (bool) {
        _claimWithdrawals(amount);
        return false;
    }

    /// @notice Withdraws phantom token for its underlying
    function withdrawPhantomToken(address token, uint256 amount) external override creditFacadeOnly returns (bool) {
        if (token != lidoWithdrawalPhantomToken) revert IncorrectStakedPhantomTokenException();
        _claimWithdrawals(amount);
        return false;
    }

    /// @dev Internal implementation of `claimWithdrawals`
    function _claimWithdrawals(uint256 amount) internal {
        _execute(abi.encodeCall(ILidoWithdrawalQueueGateway.claimWithdrawals, (amount)));
    }

    /// @dev It's not possible to deposit from WETH into the withdrawal phantom token,
    ///      hence the function is not implemented.
    function depositPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, stETH, wstETH, weth, lidoWithdrawalPhantomToken);
    }
}
