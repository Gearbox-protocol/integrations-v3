// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IDegenNFT} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IDegenNFT.sol";

import {IMidasAccessControl} from "./interfaces/external/IMidasAccessControl.sol";
import {IMidasGateway} from "./interfaces/IMidasGateway.sol";

/// @title Midas Degen NFT
/// @notice Permission gate for opening Credit Accounts against permissioned Midas markets
/// @dev Does not mint or burn real tokens. `burn` simply verifies that `from` holds the Midas greenlisted role.
contract MidasDegenNFT is IDegenNFT {
    /// @notice Thrown when attempting to open an account for a non-greenlisted address
    error NotGreenlistedException();

    bytes32 public constant override contractType = "DEGEN_NFT::MIDAS";
    uint256 public constant override version = 3_11;

    /// @notice Gateway that deployed this Degen NFT
    address public immutable gateway;

    /// @notice Midas access control contract
    address public immutable accessControl;

    /// @notice Greenlisted role checked by `burn`
    bytes32 public immutable greenlistedRole;

    constructor(address gateway_) {
        gateway = gateway_;
        accessControl = IMidasGateway(gateway_).accessControl();
        greenlistedRole = IMidasGateway(gateway_).greenlistedRole();
    }

    /// @notice Reverts unless `from` is greenlisted by Midas
    /// @dev Called by CreditFacade on account open; `amount` is unused
    function burn(address from, uint256) external view override {
        if (!IMidasAccessControl(accessControl).hasRole(greenlistedRole, from)) {
            revert NotGreenlistedException();
        }
    }

    /// @notice Serialized Degen NFT parameters
    function serialize() external view override returns (bytes memory) {
        return abi.encode(gateway, accessControl, greenlistedRole);
    }
}
