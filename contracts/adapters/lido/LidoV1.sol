// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IPoolV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPoolV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IstETH} from "../../integrations/lido/IstETH.sol";
import {ILidoV1Adapter} from "../../interfaces/lido/ILidoV1Adapter.sol";
import {LidoV1Gateway} from "../../helpers/lido/LidoV1_WETHGateway.sol";

/// @title Lido V1 adapter
/// @notice Implements logic for interacting with the Lido contract through the gateway
contract LidoV1Adapter is AbstractAdapter, ILidoV1Adapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.LIDO_V1;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice stETH token
    address public immutable override stETH;

    /// @notice WETH token
    address public immutable override weth;

    /// @notice Collateral token mask of WETH in the credit manager
    uint256 public immutable override wethTokenMask;

    /// @notice Collateral token mask of stETH in the credit manager
    uint256 public immutable override stETHTokenMask;

    /// @notice Address of Gearbox treasury
    address public immutable override treasury;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _lidoGateway Lido gateway address
    constructor(address _creditManager, address _lidoGateway)
        AbstractAdapter(_creditManager, _lidoGateway) // U:[LDO1-1]
    {
        stETH = LidoV1Gateway(payable(_lidoGateway)).stETH(); // U:[LDO1-1]
        stETHTokenMask = _getMaskOrRevert(stETH); // U:[LDO1-1]

        weth = LidoV1Gateway(payable(_lidoGateway)).weth(); // U:[LDO1-1]
        wethTokenMask = _getMaskOrRevert(weth); // U:[LDO1-1]

        treasury = IPoolV3(ICreditManagerV3(creditManager).pool()).treasury(); // U:[LDO1-1]
    }

    /// @notice Stakes given amount of WETH in Lido via Gateway
    /// @param amount Amount of WETH to deposit
    /// @dev The referral address is set to Gearbox treasury
    function submit(uint256 amount)
        external
        override
        creditFacadeOnly // U:[LDO1-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _submit(amount, false); // U:[LDO1-3]
    }

    /// @notice Stakes the entire balance of WETH in Lido via Gateway, except the specified amount
    /// @dev The referral address is set to Gearbox treasury
    function submitDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[LDO1-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[LDO1-4]

        uint256 balance = IERC20(weth).balanceOf(creditAccount); // U:[LDO1-4]
        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _submit(balance - leftoverAmount, leftoverAmount <= 1); // U:[LDO1-4]
            }
        }
    }

    /// @dev Internal implementation of `submit`.
    ///      - WETH is approved before the call because Gateway needs permission to transfer it
    ///      - stETH is enabled after the call
    ///      - WETH is only disabled when staking the entire balance
    function _submit(uint256 amount, bool disableWETH)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(weth, type(uint256).max); // U:[LDO1-3,4]
        _execute(abi.encodeCall(LidoV1Gateway.submit, (amount, treasury))); // U:[LDO1-3,4]
        _approveToken(weth, 1); // U:[LDO1-3,4]
        (tokensToEnable, tokensToDisable) = (stETHTokenMask, disableWETH ? wethTokenMask : 0);
    }
}
