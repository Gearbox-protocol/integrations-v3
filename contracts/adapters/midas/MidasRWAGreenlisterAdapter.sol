// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {IMidasRWAGreenlister, GREENLIST_OPERATOR_ROLE} from "../../interfaces/midas/IMidasRWAGreenlister.sol";
import {IMidasRWAGreenlisterAdapter} from "../../interfaces/midas/IMidasRWAGreenlisterAdapter.sol";

/// @title Midas RWA Greenlister adapter
/// @notice Implements logic for granting Midas greenlist status to credit accounts
contract MidasRWAGreenlisterAdapter is AbstractAdapter, IMidasRWAGreenlisterAdapter {
    bytes32 public constant override contractType = "ADAPTER::MIDAS_GREENLISTER";
    uint256 public constant override version = 3_10;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _greenlister Midas RWA greenlister contract address
    constructor(address _creditManager, address _greenlister) AbstractAdapter(_creditManager, _greenlister) {
        if (IMidasRWAGreenlister(_greenlister).contractType() != "GATEWAY::MIDAS_GREENLISTER") {
            revert InvalidGreenlisterException();
        }

        IAccessControl accessControl = IMidasRWAGreenlister(_greenlister).accessControl();

        if (!accessControl.hasRole(GREENLIST_OPERATOR_ROLE, _greenlister)) {
            revert NotGreenlistOperatorException();
        }
    }

    /// @inheritdoc IMidasRWAGreenlisterAdapter
    function grantGreenlist() external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(IMidasRWAGreenlister.grantGreenlist, ()));
        return false;
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract);
    }
}
