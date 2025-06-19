// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUpshiftVault} from "../../integrations/upshift/IUpshiftVault.sol";
import {IUpshiftVaultGateway} from "../../interfaces/upshift/IUpshiftVaultGateway.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

/// @title UpshiftVault withdrawal phantom token
/// @notice Phantom ERC-20 token that represents the balance of the pending and claimable withdrawals in UpshiftVault vaults
contract UpshiftVaultWithdrawalPhantomToken is PhantomERC20, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::UPSHIFT_WITHDRAW";

    uint256 public constant override version = 3_10;

    address public immutable vault;

    address public immutable gateway;

    /// @notice Constructor
    /// @param _vault The vault where the balance is tracked
    constructor(address _vault, address _gateway)
        PhantomERC20(
            IERC4626(_vault).asset(),
            string.concat("UpshiftVault withdrawn ", IERC20Metadata(IERC4626(_vault).asset()).name()),
            string.concat("wd", IERC20Metadata(IERC4626(_vault).asset()).symbol()),
            IERC20Metadata(IERC4626(_vault).asset()).decimals()
        )
    {
        vault = _vault;
        gateway = _gateway;
    }

    /// @notice Returns the amount of assets pending/claimable for withdrawal
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view returns (uint256) {
        return IUpshiftVaultGateway(gateway).pendingAssetsOf(account);
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (gateway, underlying);
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(gateway, underlying);
    }
}
