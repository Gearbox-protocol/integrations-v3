// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {ISecuritizeSwap} from "../../integrations/securitize/ISecuritizeSwap.sol";
import {ISecuritizeSwapAdapter} from "../../interfaces/securitize/ISecuritizeSwapAdapter.sol";

/// @title SecuritizeSwap Adapter
/// @notice Implements logic for interacting with the DAI / USDS wrapping contract
contract SecuritizeSwapAdapter is AbstractAdapter, ISecuritizeSwapAdapter {
    bytes32 public constant override contractType = "ADAPTER::SECURITIZE_SWAP";
    uint256 public constant override version = 3_10;

    address public immutable override dsToken;

    address public immutable override stableCoinToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _targetContract SecuritizeSwap contract
    constructor(address _creditManager, address _targetContract) AbstractAdapter(_creditManager, _targetContract) {}

    /// @notice Buys a given amount of DS tokens
    function buy(uint256, uint256) external override creditFacadeOnly returns (bool) {
        _executeSwapSafeApprove(stableCoinToken, msg.data);
        return true;
    }

    /// @notice Buys DS tokens for a given amount of stablecoin
    /// @param _stableCoinAmount Amount of stablecoin to spend
    function buyExactIn(uint256 _stableCoinAmount) external override creditFacadeOnly returns (bool) {
        _buyExactIn(_stableCoinAmount);
        return true;
    }

    /// @notice Buys DS tokens for the entire balance of stablecoin, except the specified amount
    /// @param leftoverAmount Amount of stablecoin to keep on the account
    function buyExactInDiff(uint256 leftoverAmount) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        uint256 stableCoinAmount = IERC20(stableCoinToken).balanceOf(creditAccount);
        if (stableCoinAmount <= leftoverAmount) return false;
        unchecked {
            stableCoinAmount -= leftoverAmount;
        }
        _buyExactIn(stableCoinAmount);
        return true;
    }

    function _buyExactIn(uint256 _stableCoinAmount) internal {
        uint256 dsTokenAmount = ISecuritizeSwap(targetContract).calculateDsTokenAmount(_stableCoinAmount);
        _executeSwapSafeApprove(
            stableCoinToken, abi.encodeCall(ISecuritizeSwap.buy, (dsTokenAmount, _stableCoinAmount))
        );
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, dsToken, stableCoinToken);
    }
}
