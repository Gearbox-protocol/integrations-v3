// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {ISecuritizeOnRamp} from "../../integrations/securitize/ISecuritizeOnRamp.sol";
import {ISecuritizeOnRampAdapter} from "../../interfaces/securitize/ISecuritizeOnRampAdapter.sol";

/// @title Securitize On-Ramp Adapter
/// @notice Implements logic for interacting with the DAI / USDS on-ramp contract
contract SecuritizeOnRampAdapter is AbstractAdapter, ISecuritizeOnRampAdapter {
    bytes32 public constant override contractType = "ADAPTER::SECURITIZE_ONRAMP";
    uint256 public constant override version = 3_10;

    address public immutable override dsToken;

    address public immutable override liquidityToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _targetContract SecuritizeOnRamp contract
    constructor(address _creditManager, address _targetContract) AbstractAdapter(_creditManager, _targetContract) {
        dsToken = ISecuritizeOnRamp(_targetContract).dsToken();
        liquidityToken = ISecuritizeOnRamp(_targetContract).liquidityToken();

        _getMaskOrRevert(dsToken);
        _getMaskOrRevert(liquidityToken);
    }

    /// @notice Performs an exact-in swap on the Securitize on-ramp
    /// @param liquidityAmount Amount of stablecoin to spend
    /// @param minOutAmount Minimum acceptable amount of DS tokens
    function swap(uint256 liquidityAmount, uint256 minOutAmount) external override creditFacadeOnly returns (bool) {
        _swap(liquidityAmount, minOutAmount);
        return true;
    }

    /// @notice Swaps the entire balance of stablecoin, except the specified amount,
    ///         while enforcing a minimum exchange rate between input and output tokens.
    /// @param leftoverAmount Amount of stablecoin to keep on the account
    /// @param rateMinRAY Minimum acceptable rate (dsToken per stablecoin), scaled by 1e27
    function swapDiff(uint256 leftoverAmount, uint256 rateMinRAY) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        uint256 liquidityAmount = IERC20(liquidityToken).balanceOf(creditAccount);
        if (liquidityAmount <= leftoverAmount) return false;
        unchecked {
            liquidityAmount -= leftoverAmount;
        }
        uint256 minOutAmount = (liquidityAmount * rateMinRAY) / RAY;
        _swap(liquidityAmount, minOutAmount);
        return true;
    }

    /// @dev Internal implementation for `swap` and `swapDiff`
    function _swap(uint256 liquidityAmount, uint256 minOutAmount) internal {
        _executeSwapSafeApprove(liquidityToken, abi.encodeCall(ISecuritizeOnRamp.swap, (liquidityAmount, minOutAmount)));
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, dsToken, liquidityToken);
    }
}

