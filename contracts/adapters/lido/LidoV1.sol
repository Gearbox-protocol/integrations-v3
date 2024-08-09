// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IPoolV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPoolV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IstETH} from "../../integrations/lido/IstETH.sol";
import {ILidoV1Adapter} from "../../interfaces/lido/ILidoV1Adapter.sol";
import {LidoV1Gateway} from "../../helpers/lido/LidoV1_WETHGateway.sol";

/// @title Lido V1 adapter
/// @notice Implements logic for interacting with the Lido contract through the gateway
contract LidoV1Adapter is AbstractAdapter, ILidoV1Adapter {
    bytes32 public constant override contractType = "AD_LIDO_V1";
    uint256 public constant override version = 3_10;

    /// @notice stETH token
    address public immutable override stETH;

    /// @notice WETH token
    address public immutable override weth;

    /// @notice Address of Gearbox treasury
    address public immutable override treasury;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _lidoGateway Lido gateway address
    constructor(address _creditManager, address _lidoGateway)
        AbstractAdapter(_creditManager, _lidoGateway) // U:[LDO1-1]
    {
        stETH = LidoV1Gateway(payable(_lidoGateway)).stETH(); // U:[LDO1-1]
        weth = LidoV1Gateway(payable(_lidoGateway)).weth(); // U:[LDO1-1]

        // We check that WETH and stETH are both valid collaterals
        _getMaskOrRevert(stETH); // U:[LDO1-1]
        _getMaskOrRevert(weth); // U:[LDO1-1]

        treasury = IPoolV3(ICreditManagerV3(creditManager).pool()).treasury(); // U:[LDO1-1]
    }

    /// @notice Stakes given amount of WETH in Lido via Gateway
    /// @param amount Amount of WETH to deposit
    /// @dev The referral address is set to Gearbox treasury
    function submit(uint256 amount)
        external
        override
        creditFacadeOnly // U:[LDO1-2]
        returns (bool)
    {
        _submit(amount); // U:[LDO1-3]
        return false;
    }

    /// @notice Stakes the entire balance of WETH in Lido via Gateway, except the specified amount
    /// @dev The referral address is set to Gearbox treasury
    function submitDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[LDO1-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[LDO1-4]

        uint256 balance = IERC20(weth).balanceOf(creditAccount); // U:[LDO1-4]
        if (balance > leftoverAmount) {
            unchecked {
                _submit(balance - leftoverAmount);
            }
        }
        return false;
    }

    /// @dev Internal implementation of `submit`.
    function _submit(uint256 amount) internal {
        _executeSwapSafeApprove(weth, abi.encodeCall(LidoV1Gateway.submit, (amount, treasury))); // U:[LDO1-3,4]
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, stETH, weth, treasury);
    }
}
