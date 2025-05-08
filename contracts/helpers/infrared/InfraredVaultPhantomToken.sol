// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IInfraredVault} from "../../integrations/infrared/IInfraredVault.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

/// @title InfraredVault position token
/// @notice Phantom ERC-20 token that represents the balance of the staked position in an InfraredVault
contract InfraredVaultPhantomToken is PhantomERC20, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::INFRARED";

    uint256 public constant override version = 3_10;

    /// @notice Address of the InfraredVault contract
    address public immutable vault;

    /// @notice Constructor
    /// @param _vault The InfraredVault contract where the balance is tracked
    constructor(address _vault)
        PhantomERC20(
            IInfraredVault(_vault).stakingToken(),
            string(
                abi.encodePacked("Infrared staked position ", IERC20Metadata(IInfraredVault(_vault).stakingToken()).name())
            ),
            string(abi.encodePacked("ir", IERC20Metadata(IInfraredVault(_vault).stakingToken()).symbol())),
            IERC20Metadata(IInfraredVault(_vault).stakingToken()).decimals()
        )
    {
        vault = _vault;
    }

    /// @notice Returns the amount of tokens staked in the InfraredVault
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view override returns (uint256) {
        return IInfraredVault(vault).balanceOf(account);
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (vault, underlying);
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(vault, underlying);
    }
}
