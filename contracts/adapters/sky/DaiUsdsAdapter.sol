// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IDaiUsds} from "../../integrations/sky/IDaiUsds.sol";
import {IDaiUsdsAdapter} from "../../interfaces/sky/IDaiUsdsAdapter.sol";

/// @title DaiUsds Adapter
/// @notice Implements logic for interacting with the DAI / USDS wrapping contract
contract DaiUsdsAdapter is AbstractAdapter, IDaiUsdsAdapter {
    bytes32 public constant override contractType = "AD_DAI_USDS_EXCHANGE";
    uint256 public constant override version = 3_10;

    /// @notice DAI token
    address public immutable override dai;

    /// @notice USDS token
    address public immutable override usds;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _targetContract DAI / USDS exchange contract
    constructor(address _creditManager, address _targetContract) AbstractAdapter(_creditManager, _targetContract) {
        dai = IDaiUsds(_targetContract).dai();
        usds = IDaiUsds(_targetContract).usds();

        // We check that DAI and USDS are both valid collaterals
        _getMaskOrRevert(dai);
        _getMaskOrRevert(usds);
    }

    /// @notice Swaps given amount of DAI to USDS
    /// @param wad Amount of DAI to swap
    /// @dev `usr` (recipient) is ignored as it is always the Credit Account
    function daiToUsds(address, uint256 wad) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        _daiToUsds(creditAccount, wad);
        return false;
    }

    /// @notice Swaps the entire balance of DAI to USDS, except the specified amount
    /// @param leftoverAmount Amount of DAI to keep on the account
    function daiToUsdsDiff(uint256 leftoverAmount) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(dai).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                _daiToUsds(creditAccount, balance - leftoverAmount);
            }
        }
        return false;
    }

    /// @dev Internal implementation for `daiToUsds` and `daiToUsdsDiff`
    function _daiToUsds(address creditAccount, uint256 amount) internal {
        _executeSwapSafeApprove(dai, abi.encodeCall(IDaiUsds.daiToUsds, (creditAccount, amount)));
    }

    /// @notice Swaps given amount of USDS to DAI
    /// @param wad Amount of USDS to swap
    /// @dev `usr` (recipient) is ignored as it is always the Credit Account
    function usdsToDai(address, uint256 wad) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        _usdsToDai(creditAccount, wad);
        return false;
    }

    /// @notice Swaps the entire balance of USDS to DAI, except the specified amount
    /// @param leftoverAmount Amount of USDS to keep on the account
    function usdsToDaiDiff(uint256 leftoverAmount) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(usds).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                _usdsToDai(creditAccount, balance - leftoverAmount);
            }
        }
        return false;
    }

    /// @dev Internal implementation for `usdsToDai` and `usdsToDaiDiff`
    function _usdsToDai(address creditAccount, uint256 amount) internal {
        _executeSwapSafeApprove(usds, abi.encodeCall(IDaiUsds.usdsToDai, (creditAccount, amount)));
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, dai, usds);
    }
}
