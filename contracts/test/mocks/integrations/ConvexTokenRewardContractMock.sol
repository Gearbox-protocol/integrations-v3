// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import "../../../integrations/convex/Interfaces.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {VirtualBalanceWrapper} from "./ConvexExtraRewardPoolMock.sol";

contract TokenRewardContractMock is VirtualBalanceWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for ERC20Mock;

    uint256 public constant duration = 7 days;

    address public operator;

    /// MOCK PARAMS
    mapping(address => uint256) totalRewards;

    constructor(address deposit_, address op_) {
        deposits = IDeposit(deposit_);
        operator = op_;
    }

    function stake(address, uint256) public pure returns (bool) {
        return true;
    }

    function withdraw(address, uint256) public pure returns (bool) {
        return true;
    }

    function getReward(address _account, address _token) public returns (bool) {
        uint256 reward = totalRewards[_token];
        if (reward > 0) {
            totalRewards[_token] = 0;
            ERC20Mock(_token).safeTransfer(_account, reward);
        }
        return true;
    }

    function getReward(address _token) external returns (bool) {
        getReward(msg.sender, _token);
        return true;
    }

    ///
    /// MOCK FUNCTIONS
    ///

    function addRewardAmount(address token, uint256 amount) public {
        vm.prank(ERC20Mock(token).minter());
        ERC20Mock(token).mint(address(this), amount);

        totalRewards[token] += amount;
    }
}
