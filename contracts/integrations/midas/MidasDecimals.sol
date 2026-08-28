// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

/// @title Midas decimals
/// @notice Converts token amounts between their native decimals and the 18-decimal format Midas operates in
library MidasDecimals {
    /// @dev Converts `amount` of `token` from the token's native decimals to 18 decimals
    function toE18(address token, uint256 amount) internal view returns (uint256) {
        uint256 tokenUnit = 10 ** IERC20Metadata(token).decimals();
        return tokenUnit == WAD ? amount : amount * WAD / tokenUnit;
    }

    /// @dev Converts `amount` of `token` from 18 decimals to the token's native decimals
    function fromE18(address token, uint256 amount) internal view returns (uint256) {
        uint256 tokenUnit = 10 ** IERC20Metadata(token).decimals();
        return tokenUnit == WAD ? amount : amount * tokenUnit / WAD;
    }
}
