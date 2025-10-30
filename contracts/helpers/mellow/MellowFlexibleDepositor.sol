// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMellowDepositQueue} from "../../integrations/mellow/IMellowDepositQueue.sol";

/// @title MellowFlexibleDepositor
/// @notice As Mellow's deposit queue only accepts a single deposit per account, this contract is used
///         as a disposable proxy by the queue in order to make deposits on behalf of users.
contract MellowFlexibleDepositor is Ownable {
    /// @notice Thrown when attempting to claim when there are no shares to claim.
    error NothingToClaimException();

    /// @notice Thrown when attempting to deposit when a deposit is already in progress.
    error DepositInProgressException();

    /// @notice Thrown when attempting to cancel a deposit when no deposit is in progress.
    error DepositNotInProgressException();

    /// @notice The account to make deposits on behalf of.
    address public immutable account;

    /// @notice Mellow deposit queue.
    address public immutable mellowDepositQueue;

    /// @notice The deposited asset.
    address public immutable asset;

    /// @notice The LP token of the vault.
    address public immutable vaultToken;

    /// @notice The amount of currently pending deposited assets.
    uint256 public assetsDeposited;

    constructor(address _mellowDepositQueue, address _asset, address _vaultToken, address _account)
        Ownable(msg.sender)
    {
        mellowDepositQueue = _mellowDepositQueue;
        asset = _asset;
        vaultToken = _vaultToken;
        account = _account;
    }

    /// @notice Deposits assets on behalf of the account.
    /// @param assets The amount of assets to deposit.
    /// @param referral The referral address.
    function deposit(uint256 assets, address referral) external onlyOwner {
        if (assetsDeposited > 0) {
            revert DepositInProgressException();
        }

        IERC20(asset).forceApprove(mellowDepositQueue, assets);
        IMellowDepositQueue(mellowDepositQueue).deposit(assets, referral, new bytes32[](0));

        assetsDeposited = assets;
    }

    /// @notice Cancels the deposit request.
    function cancelDepositRequest() external onlyOwner {
        if (assetsDeposited == 0) {
            revert DepositNotInProgressException();
        }

        IMellowDepositQueue(mellowDepositQueue).cancelDepositRequest();
        IERC20(asset).safeTransfer(account, assetsDeposited);

        assetsDeposited = 0;
    }

    /// @notice Claims a specific amount from a matured deposit on behalf of the account.
    function claim(uint256 amount) external onlyOwner {
        uint256 sharesBalance = IERC20(vaultToken).balanceOf(address(this));

        if (sharesBalance == 0) {
            IMellowDepositQueue(mellowDepositQueue).claim(account);
            sharesBalance = IERC20(vaultToken).balanceOf(address(this));
        }

        if (sharesBalance < amount) {
            revert NotEnoughToClaimException();
        }

        IERC20(vaultToken).safeTransfer(account, amount);

        if (sharesBalance == amount) {
            assetsDeposited = 0;
        }
    }
}
