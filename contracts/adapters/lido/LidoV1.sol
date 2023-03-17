// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "../../interfaces/IAdapter.sol";

import {IstETH} from "../../integrations/lido/IstETH.sol";
import {ILidoV1Adapter} from "../../interfaces/lido/ILidoV1Adapter.sol";
import {LidoV1Gateway} from "./LidoV1_WETHGateway.sol";

uint256 constant LIDO_STETH_LIMIT = 20000 ether;

/// @title Lido V1 adapter
/// @notice Implements logic for interacting with the Lido contract through the gateway
contract LidoV1Adapter is AbstractAdapter, ILidoV1Adapter {
    /// @notice Address of the Lido contract
    address public immutable override stETH;

    /// @notice Address of WETH
    address public immutable override weth;

    /// @notice Collateral token mask of WETH in the credit manager
    uint256 public immutable override wethTokenMask;

    /// @notice Collateral token mask of stETH in the credit manager
    uint256 public immutable override stETHTokenMask;

    /// @notice Address of Gearbox treasury
    address public immutable override treasury;

    /// @notice The amount of WETH that can be deposited through this adapter
    uint256 public override limit;

    AdapterType public constant override _gearboxAdapterType = AdapterType.LIDO_V1;
    uint16 public constant override _gearboxAdapterVersion = 2;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _lidoGateway Lido gateway address
    constructor(address _creditManager, address _lidoGateway) AbstractAdapter(_creditManager, _lidoGateway) {
        stETH = address(LidoV1Gateway(payable(_lidoGateway)).stETH()); // F: [LDOV1-1]
        stETHTokenMask = _checkToken(stETH); // F: [LDOV1-1]

        weth = addressProvider.getWethToken(); // F: [LDOV1-1]
        wethTokenMask = _checkToken(weth); // F: [LDOV1-1]

        treasury = addressProvider.getTreasuryContract(); // F: [LDOV1-1]
        limit = LIDO_STETH_LIMIT; // F: [LDOV1-1]
    }

    /// @notice Stakes given amount of WETH in Lido via Gateway
    /// @param amount Amount of WETH to deposit
    /// @dev The referral address is set to Gearbox treasury
    function submit(uint256 amount) external override creditFacadeOnly {
        _submit(amount, false); // F: [LDOV1-3]
    }

    /// @notice Stakes the entire balance of WETH in Lido via Gateway, disables WETH
    /// @dev The referral address is set to Gearbox treasury
    function submitAll() external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F: [LDOV1-2]

        uint256 balance = IERC20(weth).balanceOf(creditAccount);
        if (balance <= 1) return;

        unchecked {
            _submit(balance - 1, true); // F: [LDOV1-4]
        }
    }

    /// @dev Internal implementation of `submit` and `submitAll`
    ///      - WETH is approved before the call because Gateway needs permission to transfer it
    ///      - stETH is enabled after the call
    ///      - WETH is only disabled when staking the entire balance
    function _submit(uint256 amount, bool disableWETH) internal {
        if (amount > limit) revert LimitIsOverException(); // F: [LDOV1-5]
        unchecked {
            limit -= amount; // F: [LDOV1-5]
        }

        _approveToken(weth, type(uint256).max);
        _execute(abi.encodeCall(LidoV1Gateway.submit, (amount, treasury)));
        _approveToken(weth, 1);
        _changeEnabledTokens(stETHTokenMask, disableWETH ? wethTokenMask : 0);
    }

    /// @notice Set a new deposit limit
    /// @param _limit New value for the limit
    function setLimit(uint256 _limit)
        external
        override
        configuratorOnly // F: [LDOV1-6]
    {
        limit = _limit; // F: [LDOV1-7]
        emit NewLimit(_limit); // F: [LDOV1-7]
    }
}
