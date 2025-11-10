// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IMellowFlexibleDepositGateway} from "../../interfaces/mellow/IMellowFlexibleDepositGateway.sol";
import {IMellowDepositQueue} from "../../integrations/mellow/IMellowDepositQueue.sol";
import {IMellowFlexibleVault} from "../../integrations/mellow/IMellowFlexibleVault.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MellowFlexibleDepositor} from "./MellowFlexibleDepositor.sol";

/// @title Mellow Flexible Vaults deposit gateway
/// @notice Acts as an intermediary between Gearbox Credit Acocunts and the Mellow deposit queue to avoid unexpected balance changes,
///         and allow partial claiming of matured deposits.
contract MellowFlexibleDepositGateway is IMellowFlexibleDepositGateway {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::MELLOW_DEPOSIT_QUEUE";
    uint256 public constant override version = 3_10;

    /// @notice The deposit queue contract
    address public immutable mellowDepositQueue;

    /// @notice The asset deposited into the vault through the queue
    address public immutable asset;

    /// @notice The vault token received from deposits
    address public immutable vaultToken;

    /// @notice The master depositor contract
    address public immutable masterDepositor;

    /// @notice Mapping of accounts to corresponding depositor contracts,
    ///         which interact directly with the queue
    mapping(address => address) public accountToDepositor;

    constructor(address _mellowDepositQueue) {
        mellowDepositQueue = _mellowDepositQueue;
        asset = IMellowDepositQueue(mellowDepositQueue).asset();
        vaultToken = IMellowFlexibleVault(IMellowDepositQueue(mellowDepositQueue).vault()).shareManager();
        masterDepositor = address(new MellowFlexibleDepositor(mellowDepositQueue, asset, vaultToken));
    }

    /// @notice Deposits assets into the vault through the queue
    /// @param assets The amount of assets to deposit
    /// @param referral The referral address for the deposit
    function deposit(uint256 assets, address referral, bytes32[] calldata) external {
        address depositor = _getDepositorForAccount(msg.sender);
        IERC20(asset).safeTransferFrom(msg.sender, depositor, assets);
        MellowFlexibleDepositor(depositor).deposit(assets, referral);
    }

    /// @notice Cancels a pending deposit request
    function cancelDepositRequest() external {
        address depositor = _getDepositorForAccount(msg.sender);
        MellowFlexibleDepositor(depositor).cancelDepositRequest();
    }

    /// @notice Claims a specific amount from mature deposits
    function claim(uint256 amount) external {
        address depositor = _getDepositorForAccount(msg.sender);
        MellowFlexibleDepositor(depositor).claim(amount);
    }

    /// @notice Returns the amount of assets pending for a deposit
    function getPendingAssets(address account) external view returns (uint256) {
        address depositor = accountToDepositor[account];
        if (depositor == address(0)) {
            return 0;
        }
        return MellowFlexibleDepositor(depositor).getPendingAssets();
    }

    /// @notice Returns the amount of shares claimable from mature deposits
    function getClaimableShares(address account) external view returns (uint256) {
        address depositor = accountToDepositor[account];
        if (depositor == address(0)) {
            return 0;
        }
        return MellowFlexibleDepositor(depositor).getClaimableShares();
    }

    /// @dev Internal function to get the depositor contract for an account or create a new one if it doesn't exist
    function _getDepositorForAccount(address account) internal returns (address) {
        address depositor = accountToDepositor[account];
        if (depositor == address(0)) {
            depositor = Clones.clone(masterDepositor);
            MellowFlexibleDepositor(depositor).setAccount(account);
            accountToDepositor[account] = depositor;
        }
        return depositor;
    }
}
