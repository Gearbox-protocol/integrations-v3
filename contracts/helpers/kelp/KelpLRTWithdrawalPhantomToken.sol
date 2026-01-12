// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

import {IKelpLRTWithdrawalManagerGateway} from "../../interfaces/kelp/IKelpLRTWithdrawalManagerGateway.sol";

/// @title Kelp LRT Withdrawal Phantom token
/// @notice Phantom ERC-20 token that represents the balance of the pending and claimable withdrawals in Kelp LRT Withdrawal Manager
contract KelpLRTWithdrawalPhantomToken is PhantomERC20, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::KELP_WITHDRAWAL";

    uint256 public constant override version = 3_10;

    address public immutable withdrawalManagerGateway;

    address public immutable tokenOut;

    /// @notice Constructor
    constructor(address _withdrawalManagerGateway, address _tokenOut)
        PhantomERC20(
            _tokenOut,
            string.concat("Kelp pending withdrawal ", IERC20Metadata(_tokenOut).name()),
            string.concat("kpw", IERC20Metadata(_tokenOut).symbol()),
            IERC20Metadata(_tokenOut).decimals()
        )
    {
        withdrawalManagerGateway = _withdrawalManagerGateway;
        tokenOut = _tokenOut;
    }

    /// @notice Returns the amount of assets pending/claimable for a withdrawal
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view returns (uint256 balance) {
        (uint256 pendingAssetAmount, uint256 claimableAssetAmount) = IKelpLRTWithdrawalManagerGateway(
            withdrawalManagerGateway
        ).getPendingAndClaimableAssetAmounts(account, tokenOut);
        return pendingAssetAmount + claimableAssetAmount;
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (withdrawalManagerGateway, tokenOut);
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(withdrawalManagerGateway, tokenOut);
    }
}
