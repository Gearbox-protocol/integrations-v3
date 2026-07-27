// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

bytes32 constant STANDARD_GREENLISTED_ROLE = keccak256("GREENLISTED_ROLE");

interface IMidasAccessControl {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;
}
