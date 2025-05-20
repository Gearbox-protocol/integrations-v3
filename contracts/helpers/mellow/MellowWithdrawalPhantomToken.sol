// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMellowSimpleLRTVault, IMellowWithdrawalQueue} from "../../integrations/mellow/IMellowSimpleLRTVault.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

/// @title MellowLRT withdrawal phantom token
/// @notice Phantom ERC-20 token that represents the balance of the pending and claimable withdrawals in Mellow vaults
contract MellowWithdrawalPhantomToken is PhantomERC20, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::MELLOW_WITHDRAWAL";

    uint256 public constant override version = 3_10;

    address public immutable vault;

    address public immutable withdrawalQueue;

    /// @notice Constructor
    /// @param _vault The vault where the balance is tracked
    constructor(address _vault)
        PhantomERC20(
            IMellowSimpleLRTVault(_vault).asset(),
            string.concat("Mellow withdrawn ", IERC20Metadata(IMellowSimpleLRTVault(_vault).asset()).name()),
            string.concat("wd", IERC20Metadata(IMellowSimpleLRTVault(_vault).asset()).symbol()),
            IERC20Metadata(IMellowSimpleLRTVault(_vault).asset()).decimals()
        )
    {
        vault = _vault;
        withdrawalQueue = IMellowSimpleLRTVault(_vault).withdrawalQueue();
    }

    /// @notice Returns the amount of assets pending/claimable for withdrawal
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view returns (uint256) {
        return IMellowWithdrawalQueue(withdrawalQueue).balanceOf(account);
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (vault, underlying);
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(vault, underlying);
    }
}
