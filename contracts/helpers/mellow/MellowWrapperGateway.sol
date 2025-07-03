// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMellowWrapper} from "../../integrations/mellow/IMellowWrapper.sol";
import {IMellowWrapperGateway} from "../../interfaces/mellow/IMellowWrapperGateway.sol";

contract MellowWrapperGateway is IMellowWrapperGateway {
    bytes32 public constant override contractType = "GATEWAY::MELLOW_WRAPPER";

    uint256 public constant override version = 3_10;

    address public immutable mellowWrapper;

    constructor(address _mellowWrapper) {
        mellowWrapper = _mellowWrapper;
    }

    function deposit(address depositToken, uint256 amount, address vault, address receiver, address referral)
        public
        returns (uint256 shares)
    {
        IERC20(depositToken).transferFrom(msg.sender, mellowWrapper, amount);
        return IMellowWrapper(mellowWrapper).deposit(depositToken, amount, vault, receiver, referral);
    }
}
