// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBaseRewardPool} from "../../integrations/convex/IBaseRewardPool.sol";
import {IBooster} from "../../integrations/convex/IBooster.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

/// @title Convex staked position token
/// @notice Phantom ERC-20 token that represents the balance of the staking position in Convex pools
contract ConvexStakedPositionToken is PhantomERC20, IPhantomToken {
    address public immutable pool;
    address public immutable booster;
    address public immutable curveToken;

    /// @notice Constructor
    /// @param _pool The Convex pool where the balance is tracked
    /// @param _lptoken The Convex LP token that is staked in the pool
    /// @param _booster The Convex booster associated with respective pool
    constructor(address _pool, address _lptoken, address _booster)
        PhantomERC20(
            _lptoken,
            string(abi.encodePacked("Convex Staked Position ", IERC20Metadata(_lptoken).name())),
            string(abi.encodePacked("stk", IERC20Metadata(_lptoken).symbol())),
            IERC20Metadata(_lptoken).decimals()
        )
    {
        pool = _pool;
        booster = _booster;

        uint256 pid = IBaseRewardPool(pool).pid();
        IBooster.PoolInfo memory pInfo = IBooster(booster).poolInfo(pid);

        curveToken = pInfo.lptoken;
    }

    /// @notice Returns the amount of Convex LP tokens staked in the pool
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view returns (uint256) {
        return IERC20(pool).balanceOf(account);
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (pool, underlying);
    }
}
