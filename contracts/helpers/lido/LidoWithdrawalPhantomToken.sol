// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";
import {ILidoWithdrawalQueueGateway} from "../../interfaces/lido/ILidoWithdrawalQueueGateway.sol";

/// @title Lido withdrawal phantom token
/// @notice Phantom ERC-20 token that represents the balance of the pending and claimable withdrawals in Lido withdrawal queue
contract LidoWithdrawalPhantomToken is PhantomERC20, Ownable, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::LIDO_WITHDRAWAL";

    uint256 public constant override version = 3_10;

    address public immutable withdrawalQueueGateway;

    /// @notice Constructor
    /// @param _withdrawalQueueGateway The address of the Lido withdrawal queue gateway
    constructor(address _withdrawalQueueGateway)
        PhantomERC20(ILidoWithdrawalQueueGateway(_withdrawalQueueGateway).weth(), "Lido withdrawl ETH", "unstETH", 18)
    {
        withdrawalQueueGateway = _withdrawalQueueGateway;
    }

    /// @notice Returns the amount of assets pending/claimable for withdrawal
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view returns (uint256 balance) {
        balance = ILidoWithdrawalQueueGateway(withdrawalQueueGateway).getPendingWETH(account);
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (withdrawalQueueGateway, underlying);
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(withdrawalQueueGateway, underlying);
    }
}
