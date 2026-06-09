// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IDegenNFT} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IDegenNFT.sol";

import {GREENLISTED_ROLE} from "../../interfaces/midas/IMidasRWAGreenlister.sol";

/// @title Midas RWA Degen NFT
/// @notice Restricts account opening to addresses greenlisted in the Midas AccessControl contract
contract MidasRWADegenNFT is IDegenNFT {
    bytes32 public constant override contractType = "DEGEN_NFT::MIDAS";
    uint256 public constant override version = 3_10;

    /// @notice Thrown when the address is not greenlisted in the Midas AccessControl contract
    error NotGreenlistedException();

    /// @notice Emitted when a greenlisted address is granted access to open a credit account
    event CreditAccountAccessGranted(address indexed account);

    /// @notice External Midas AccessControl contract
    IAccessControl public immutable accessControl;

    constructor(address _accessControl) {
        accessControl = IAccessControl(_accessControl);
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(accessControl);
    }

    function burn(address from, uint256) external override {
        if (!accessControl.hasRole(GREENLISTED_ROLE, from)) revert NotGreenlistedException();
        emit CreditAccountAccessGranted(from);
    }
}
