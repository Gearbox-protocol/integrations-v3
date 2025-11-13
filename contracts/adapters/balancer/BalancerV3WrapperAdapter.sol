// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IBalancerV3Wrapper} from "../../integrations/balancer/IBalancerV3Wrapper.sol";
import {IBalancerV3WrapperAdapter} from "../../interfaces/balancer/IBalancerV3WrapperAdapter.sol";

/// @title Balancer V3 Wrapper adapter
/// @notice Implements logic allowing CAs to wrap BalancerV3 BPT into a wrapper that protects
///         against unexpected BPT flash mints
contract BalancerV3WrapperAdapter is AbstractAdapter, IBalancerV3WrapperAdapter {
    bytes32 public constant override contractType = "ADAPTER::BALANCER_V3_WRAPPER";
    uint256 public constant override version = 3_10;

    /// @notice The BPT that is wrapped
    address public immutable override balancerPoolToken;

    constructor(address _creditManager, address _wrapper) AbstractAdapter(_creditManager, _wrapper) {
        balancerPoolToken = IBalancerV3Wrapper(_wrapper).balancerPoolToken();

        _getMaskOrRevert(balancerPoolToken);
        _getMaskOrRevert(targetContract);
    }

    /// @notice Wraps a specified amount of BPT
    /// @param amount The amount of BPT to wrap
    function mint(uint256 amount) external override creditFacadeOnly returns (bool useSafePrices) {
        _mint(amount);
        return false;
    }

    /// @notice Wraps the entire balance of BPT from the credit account, except the specified amount
    /// @param leftoverAmount The amount of BPT to keep on the account
    function mintDiff(uint256 leftoverAmount) external override creditFacadeOnly returns (bool useSafePrices) {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(balancerPoolToken).balanceOf(creditAccount);

        if (balance <= leftoverAmount) return false;
        unchecked {
            balance -= leftoverAmount;
        }
        _mint(balance);
        return false;
    }

    /// @dev Internal implementation for the mint function
    function _mint(uint256 amount) internal {
        _executeSwapSafeApprove(balancerPoolToken, abi.encodeCall(IBalancerV3Wrapper.mint, (amount)));
    }

    /// @notice Unwraps a specified amount of BPT
    /// @param amount The amount of BPT to unwrap
    function burn(uint256 amount) external override creditFacadeOnly returns (bool useSafePrices) {
        _burn(amount);
        return false;
    }

    /// @notice Unwraps the entire balance of wrapperfrom the credit account, except the specified amount
    /// @param leftoverAmount The amount of wrapper token to keep on the account
    function burnDiff(uint256 leftoverAmount) external override creditFacadeOnly returns (bool useSafePrices) {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(targetContract).balanceOf(creditAccount);

        if (balance <= leftoverAmount) return false;
        unchecked {
            balance -= leftoverAmount;
        }
        _burn(balance);
        return false;
    }

    /// @dev Internal implementation for the burn function
    function _burn(uint256 amount) internal {
        _execute(abi.encodeCall(IBalancerV3Wrapper.burn, (amount)));
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(creditManager, targetContract, balancerPoolToken);
    }
}
