// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPool4626} from "@gearbox-protocol/core-v3/contracts/interfaces/IPool4626.sol";
import {IAddressProvider} from "@gearbox-protocol/core-v2/contracts/interfaces/IAddressProvider.sol";
import {IContractsRegister} from "@gearbox-protocol/core-v2/contracts/interfaces/IContractsRegister.sol";
import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

import {IstETH} from "../../integrations/lido/IstETH.sol";
import {IwstETH} from "../../integrations/lido/IwstETH.sol";
import {IwstETHGateway} from "../../interfaces/lido/IwstETHGateway.sol";

/// @title wstETH Gateway
/// @notice Allows LPs to add/remove stETH to/from wstETH liquidity pool
contract WstETHGateway is IwstETHGateway {
    using SafeERC20 for IERC20;

    /// @inheritdoc IwstETHGateway
    IPool4626 public immutable override pool;

    /// @inheritdoc IwstETHGateway
    IwstETH public immutable override wstETH;

    /// @inheritdoc IwstETHGateway
    IstETH public immutable override stETH;

    /// @notice Constructor
    /// @param _pool wstETH pool address
    constructor(address _pool) {
        if (_pool == address(0)) revert ZeroAddressException();

        IContractsRegister cr =
            IContractsRegister(IAddressProvider(IPool4626(_pool).addressProvider()).getContractsRegister());
        if (!cr.isPool(_pool)) revert NotRegisteredPoolException();

        pool = IPool4626(_pool);
        wstETH = IwstETH(pool.underlyingToken());
        stETH = IstETH(wstETH.stETH());

        wstETH.approve(address(pool), type(uint256).max);
        stETH.approve(address(wstETH), type(uint256).max);
    }

    /// @inheritdoc IwstETHGateway
    function depositReferral(uint256 assets, address receiver, uint16 referralCode)
        external
        override
        returns (uint256 shares)
    {
        IERC20(stETH).safeTransferFrom(msg.sender, address(this), assets);

        _ensureWrapperAllowance(assets);
        uint256 wstETHAmount = wstETH.wrap(assets);

        _ensurePoolAllowance(wstETHAmount);
        shares = pool.depositReferral(wstETHAmount, receiver, referralCode);
    }

    /// @inheritdoc IwstETHGateway
    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256 assets) {
        uint256 wstETHAmount = pool.redeem(shares, address(this), owner);

        assets = wstETH.unwrap(wstETHAmount);

        IERC20(stETH).safeTransfer(receiver, assets);
    }

    /// @dev Sets wstETH's allowance for gateway's stETH to `type(uint256).max` if it falls below `amount`
    function _ensureWrapperAllowance(uint256 amount) internal {
        if (stETH.allowance(address(this), address(wstETH)) < amount) {
            IERC20(stETH).safeApprove(address(wstETH), type(uint256).max);
        }
    }

    /// @dev Sets pool's allowance for gateway's wstETH to `type(uint256).max` if it falls below `amount`
    function _ensurePoolAllowance(uint256 amount) internal {
        if (wstETH.allowance(address(this), address(pool)) < amount) {
            IERC20(wstETH).safeApprove(address(pool), type(uint256).max);
        }
    }
}
