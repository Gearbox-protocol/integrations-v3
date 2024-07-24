// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IZircuitPool} from "../../integrations/zircuit/IZircuitPool.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

/// @title Zircuit staked position token
/// @notice Phantom ERC-20 token that represents the balance of the staking position in a Zircuit pool
contract ZircuitPhantomToken is PhantomERC20, IPhantomToken {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "PT_ZIRCUIT";

    address public immutable zircuitPool;

    /// @notice Constructor
    /// @param _pool The Zircuit staking pool
    /// @param _token The token to track
    constructor(address _pool, address _token)
        PhantomERC20(
            _token,
            string(abi.encodePacked("Zircuit staked position ", IERC20Metadata(_token).name())),
            string(abi.encodePacked("z", IERC20Metadata(_token).symbol())),
            IERC20Metadata(_token).decimals()
        )
    {
        zircuitPool = _pool;
    }

    /// @notice Returns the amount of token staked in the Zircuit pool by an account
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view override returns (uint256) {
        return IZircuitPool(zircuitPool).balance(underlying, account);
    }

    /// @notice Returns the total amount of certain token staked in the Zircuit pool
    function totalSupply() public view override returns (uint256) {
        return IERC20(underlying).balanceOf(zircuitPool);
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (zircuitPool, underlying);
    }
}
