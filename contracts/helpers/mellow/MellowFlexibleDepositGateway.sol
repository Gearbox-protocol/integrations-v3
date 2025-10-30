// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IMellowFlexibleDepositGateway} from "../../interfaces/mellow/IMellowFlexibleDepositGateway.sol";
import {IMellowDepositQueue} from "../../integrations/mellow/IMellowDepositQueue.sol";
import {IMellowFlexibleVault} from "../../integrations/mellow/IMellowFlexibleVault.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MellowFlexibleDepositor} from "./MellowFlexibleDepositor.sol";

contract MellowFlexibleDepositGateway is IMellowFlexibleDepositGateway {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::UPSHIFT_VAULT";
    uint256 public constant override version = 3_10;

    address public immutable mellowDepositQueue;

    address public immutable asset;

    address public immutable vaultToken;

    mapping(address => address) public immutable accountToDepositor;

    constructor(address _mellowDepositQueue) {
        mellowDepositQueue = _mellowDepositQueue;
        asset = IMellowDepositQueue(mellowDepositQueue).asset();
        vaultToken = IMellowFlexibleVault(IMellowDepositQueue(mellowDepositQueue).vault()).shareManager();
    }

    function deposit(uint256 assets, address referral, bytes32[] calldata) external {
        address depositor = _getDepositorForAccount(msg.sender);
        IERC20(asset).safeTransferFrom(msg.sender, depositor, assets);
        MellowFlexibleDepositor(depositor).deposit(assets, referral);
    }

    function cancelDepositRequest() external {
        address depositor = _getDepositorForAccount(msg.sender);
        MellowFlexibleDepositor(depositor).cancelDepositRequest();
    }

    function claim(uint256 amount) external {
        address depositor = _getDepositorForAccount(msg.sender);
        MellowFlexibleDepositor(depositor).claim(amount);
    }

    function _getDepositorForAccount(address account) internal returns (address) {
        address depositor = accountToDepositor[account];
        if (depositor == address(0)) {
            depositor = address(new MellowFlexibleDepositor(mellowDepositQueue, asset, vaultToken, account));
            accountToDepositor[account] = depositor;
        }
        return depositor;
    }
}
