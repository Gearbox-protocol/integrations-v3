// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {
    AP_TREASURY,
    IAddressProviderV3,
    NO_VERSION_CONTROL
} from "@gearbox-protocol/core-v3/contracts/interfaces/IAddressProviderV3.sol";

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
    constructor(address _creditManager, address _lidoGateway) AbstractAdapter(_creditManager, _lidoGateway) {
        stETH = LidoV1Gateway(payable(_lidoGateway)).stETH(); // F: [LDOV1-1]
        stETHTokenMask = _getMaskOrRevert(stETH); // F: [LDOV1-1]

        weth = LidoV1Gateway(payable(_lidoGateway)).weth(); // F: [LDOV1-1]
        wethTokenMask = _getMaskOrRevert(weth); // F: [LDOV1-1]

        treasury = IAddressProviderV3(addressProvider).getAddressOrRevert(AP_TREASURY, NO_VERSION_CONTROL); // F: [LDOV1-1]
    }

    /// @notice Stakes given amount of WETH in Lido via Gateway
    /// @param amount Amount of WETH to deposit
    /// @dev The referral address is set to Gearbox treasury
    function submit(uint256 amount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _submit(amount, false); // F: [LDOV1-3]
    }

    /// @notice Stakes the entire balance of WETH in Lido via Gateway, except the specified amount
    /// @dev The referral address is set to Gearbox treasury
    function submitDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) = _submitDiff(leftoverAmount);
    }

    /// @notice Stakes the entire balance of WETH in Lido via Gateway, disables WETH
    /// @dev The referral address is set to Gearbox treasury
    function submitAll() external override creditFacadeOnly returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        (tokensToEnable, tokensToDisable) = _submitDiff(1);
    }

    /// @dev Internal implementation for `submitDiff` and `submitAll`.
    function _submitDiff(uint256 leftoverAmount) internal returns (uint256 tokensToEnable, uint256 tokensToDisable) {
        address creditAccount = _creditAccount(); // F: [LDOV1-2]

        uint256 balance = IERC20(weth).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) = _submit(balance - leftoverAmount, leftoverAmount <= 1); // F: [LDOV1-4]
            }
        }
    }

    /// @dev Internal implementation of `submit` and `submitAll`
    ///      - WETH is approved before the call because Gateway needs permission to transfer it
    ///      - stETH is enabled after the call
    ///      - WETH is only disabled when staking the entire balance
    function _submit(uint256 amount, bool disableWETH)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(weth, type(uint256).max);
        _execute(abi.encodeCall(LidoV1Gateway.submit, (amount, treasury)));
        _approveToken(weth, 1);
        (tokensToEnable, tokensToDisable) = (stETHTokenMask, disableWETH ? wethTokenMask : 0);
    }
}
