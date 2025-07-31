// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IStateSerializer} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IStateSerializer.sol";
import {ERC4626Adapter} from "../erc4626/ERC4626Adapter.sol";
import {IERC4626Adapter} from "../../interfaces/erc4626/IERC4626Adapter.sol";
import {IMellowSimpleLRTVault} from "../../integrations/mellow/IMellowSimpleLRTVault.sol";
import {IMellow4626VaultAdapter} from "../../interfaces/mellow/IMellow4626VaultAdapter.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Mellow DVV vault adapter
/// @notice Implements logic allowing CAs to interact with Mellow DVV vault
contract MellowDVVAdapter is ERC4626Adapter {
    uint256 public constant override version = 3_10;
    bytes32 public constant override contractType = "ADAPTER::MELLOW_DVV";

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault ERC4626 vault address
    constructor(address _creditManager, address _vault) ERC4626Adapter(_creditManager, _vault, address(0)) {}

    function _deposit(address, uint256) internal pure override returns (bool) {
        revert NotImplementedException();
    }

    function _mint(address, uint256) internal pure override returns (bool) {
        revert NotImplementedException();
    }
}
