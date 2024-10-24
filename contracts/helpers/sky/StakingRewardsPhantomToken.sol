// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PhantomERC20} from "@gearbox-protocol/core-v2/contracts/tokens/PhantomERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IStakingRewards} from "../../integrations/sky/IStakingRewards.sol";

/// @title StakingRewards position token
/// @notice Phantom ERC-20 token that represents the balance of the staked position in a StakingRewards pool
contract StakingRewardsPhantomToken is PhantomERC20 {
    address public immutable pool;

    /// @notice Constructor
    /// @param _pool The rewards pool where the balance is tracked
    constructor(address _pool)
        PhantomERC20(
            IStakingRewards(_pool).stakingToken(),
            string(
                abi.encodePacked(
                    "StakingRewards staked position ", IERC20Metadata(IStakingRewards(_pool).stakingToken()).name()
                )
            ),
            string(abi.encodePacked("stk", IERC20Metadata(IStakingRewards(_pool).stakingToken()).symbol())),
            IERC20Metadata(IStakingRewards(_pool).stakingToken()).decimals()
        )
    {
        pool = _pool;
    }

    /// @notice Returns the amount of underlying tokens staked in the pool
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view returns (uint256) {
        return IERC20(pool).balanceOf(account);
    }
}
