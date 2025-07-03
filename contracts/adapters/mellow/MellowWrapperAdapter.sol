// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IMellowWrapperAdapter, MellowVaultStatus} from "../../interfaces/mellow/IMellowWrapperAdapter.sol";
import {IMellowWrapper} from "../../integrations/mellow/IMellowWrapper.sol";

/// @title Mellow Wrapper adapter
/// @notice Implements logic allowing CAs to interact with Mellow Wrapper
contract MellowWrapperAdapter is AbstractAdapter, IMellowWrapperAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant version = 3_10;
    bytes32 public constant contractType = "ADAPTER::MELLOW_WRAPPER";

    address public immutable referral;

    address public immutable weth;

    EnumerableSet.AddressSet private _allowedVaults;

    constructor(address _creditManager, address _mellowWrapper, address _referral)
        AbstractAdapter(_creditManager, _mellowWrapper)
    {
        referral = _referral;
        weth = IMellowWrapper(_mellowWrapper).WETH();

        _getMaskOrRevert(weth);
    }

    /// @notice Deposits an amount of WETH into a vault
    /// @param amount The amount of WETH to deposit
    /// @param vault The vault to deposit into
    /// @notice `depositToken`, `receiver`, and `referral` are ignored, as these parameters are fixed
    function deposit(address, uint256 amount, address vault, address, address)
        external
        creditFacadeOnly
        returns (bool)
    {
        if (!_allowedVaults.contains(vault)) revert VaultNotAllowedException(vault);

        address creditAccount = _creditAccount();

        _deposit(creditAccount, vault, amount);

        return false;
    }

    /// @notice Deposits the entire balance of WETH into a vault, except the specified amount
    /// @param leftoverAmount Amount of WETH to leave on the Credit Account
    /// @param vault The vault to deposit into
    function depositDiff(uint256 leftoverAmount, address vault) external creditFacadeOnly returns (bool) {
        if (!_allowedVaults.contains(vault)) revert VaultNotAllowedException(vault);

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(weth).balanceOf(creditAccount);

        if (amount <= leftoverAmount) return false;

        unchecked {
            amount = amount - leftoverAmount;
        }

        _deposit(creditAccount, vault, amount);

        return false;
    }

    /// @dev Internal implementation for `deposit` and `depositDiff`
    function _deposit(address creditAccount, address vault, uint256 amount) internal {
        _executeSwapSafeApprove(
            weth, abi.encodeCall(IMellowWrapper.deposit, (weth, amount, vault, creditAccount, referral))
        );
    }

    // ---- //
    // DATA //
    // ---- //

    /// @notice Returns the list of allowed vaults
    function allowedVaults() public view returns (address[] memory) {
        return _allowedVaults.values();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, allowedVaults());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Changes the allowed status of several vaults
    function setVaultStatusBatch(MellowVaultStatus[] calldata vaults) external configuratorOnly {
        uint256 len = vaults.length;
        for (uint256 i; i < len; ++i) {
            if (vaults[i].allowed) {
                _getMaskOrRevert(vaults[i].vault);
                _allowedVaults.add(vaults[i].vault);
            } else {
                _allowedVaults.remove(vaults[i].vault);
            }
            emit SetVaultStatus(vaults[i].vault, vaults[i].allowed);
        }
    }
}
