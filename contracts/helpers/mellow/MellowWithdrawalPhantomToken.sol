// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IMellowMultiVault, IMellowWithdrawalQueue, Subvault} from "../../integrations/mellow/IMellowMultiVault.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

/// @title MellowLRT withdrawal phantom token
/// @notice Phantom ERC-20 token that represents the balance of the pending and claimable withdrawals in Mellow vaults
contract MellowWithdrawalPhantomToken is PhantomERC20, Ownable, IPhantomToken {
    event SetClaimer(address indexed claimer);

    error SubvaultClaimerMismatchException();

    bytes32 public constant override contractType = "PHANTOM_TOKEN::MELLOW_WITHDRAWAL";

    uint256 public constant override version = 3_12;

    address public immutable multiVault;

    address public claimer;

    /// @notice Constructor
    /// @param _ioProxy The address of the Instance Owner proxy
    /// @param _multiVault The MultiVault where the pending assets are tracked
    /// @param _claimer The address of the initial Claimer contract
    constructor(address _ioProxy, address _multiVault, address _claimer)
        PhantomERC20(
            IERC4626(_multiVault).asset(),
            string.concat("Mellow withdrawn ", IERC20Metadata(_multiVault).name()),
            string.concat("wd", IERC20Metadata(_multiVault).symbol()),
            IERC20Metadata(IERC4626(_multiVault).asset()).decimals()
        )
    {
        _transferOwnership(_ioProxy);

        multiVault = _multiVault;
        claimer = _claimer;
    }

    /// @notice Returns the amount of assets pending/claimable for withdrawal
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view returns (uint256 balance) {
        uint256 nSubvaults = IMellowMultiVault(multiVault).subvaultsCount();

        for (uint256 i = 0; i < nSubvaults; ++i) {
            Subvault memory subvault = IMellowMultiVault(multiVault).subvaultAt(i);

            if (subvault.withdrawalQueue == address(0)) continue;

            balance += IMellowWithdrawalQueue(subvault.withdrawalQueue).pendingAssetsOf(account)
                + IMellowWithdrawalQueue(subvault.withdrawalQueue).claimableAssetsOf(account);
        }
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (claimer, underlying);
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(claimer, underlying);
    }

    /// @notice Sets the address of the Claimer contract
    function setClaimer(address _claimer) external onlyOwner {
        if (_claimer != claimer) {
            uint256 nSubvaults = IMellowMultiVault(multiVault).subvaultsCount();

            for (uint256 i = 0; i < nSubvaults; ++i) {
                Subvault memory subvault = IMellowMultiVault(multiVault).subvaultAt(i);

                if (subvault.withdrawalQueue == address(0)) continue;

                address queueClaimer = IMellowWithdrawalQueue(subvault.withdrawalQueue).claimer();

                if (queueClaimer != _claimer) revert SubvaultClaimerMismatchException();
            }

            claimer = _claimer;
            emit SetClaimer(_claimer);
        }
    }
}
