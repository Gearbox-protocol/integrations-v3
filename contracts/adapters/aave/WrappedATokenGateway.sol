// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IPool4626} from "@gearbox-protocol/core-v2/contracts/interfaces/IPool4626.sol";
import {IAddressProvider} from "@gearbox-protocol/core-v2/contracts/interfaces/IAddressProvider.sol";
import {IContractsRegister} from "@gearbox-protocol/core-v2/contracts/interfaces/IContractsRegister.sol";
import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

import {IAToken} from "../../integrations/aave/IAToken.sol";
import {IWrappedAToken} from "../../interfaces/aave/IWrappedAToken.sol";
import {IWrappedATokenGateway} from "../../interfaces/aave/IWrappedATokenGateway.sol";

/// @title waToken Gateway
/// @notice Allows LPs to add/remove aTokens to/from waToken liquidity pool
contract WrappedATokenGateway is IWrappedATokenGateway {
    /// @notice waToken pool
    IPool4626 public immutable override pool;

    /// @notice waToken address
    IWrappedAToken public immutable override waToken;

    /// @notice aToken address
    IAToken public immutable override aToken;

    /// @notice Constructor
    /// @param _pool waToken pool address
    constructor(address _pool) {
        if (_pool == address(0)) revert ZeroAddressException();

        IContractsRegister cr =
            IContractsRegister(IAddressProvider(IPool4626(_pool).addressProvider()).getContractsRegister());
        if (!cr.isPool(_pool)) revert NotRegisteredPoolException();

        pool = IPool4626(_pool);
        waToken = IWrappedAToken(pool.underlyingToken());
        aToken = waToken.aToken();

        waToken.approve(address(pool), type(uint256).max); // non-spendable
        aToken.approve(address(waToken), type(uint256).max); // spendable
    }

    /// @notice Deposit aTokens into waToken liquidity pool
    /// @dev Gateway must be approved to spend aTokens from `msg.sender` before the call
    /// @param assets Amount of aTokens to deposit to the pool
    /// @param receiver Account that should receive dTokens
    /// @param referralCode Referral code, for potential rewards
    /// @return shares Amount of dTokens minted to `receiver`
    function depositReferral(uint256 assets, address receiver, uint16 referralCode)
        external
        override
        returns (uint256 shares)
    {
        aToken.transferFrom(msg.sender, address(this), assets);

        _ensureWrapperAllowance(assets);
        uint256 waTokenAmount = waToken.deposit(assets);

        shares = pool.depositReferral(waTokenAmount, receiver, referralCode);
    }

    /// @notice Redeem aTokens from waToken liquidity pool
    /// @dev Gateway must be approved to spend dTokens from `owner` before the call
    /// @param shares Amount of dTokens to burn
    /// @param receiver Account that should receive aTokens
    /// @param owner Account to burn dTokens from
    /// @return assets Amount of aTokens sent to `receiver`
    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256 assets) {
        uint256 waTokenAmount = pool.redeem(shares, address(this), owner);

        assets = waToken.withdraw(waTokenAmount);
        aToken.transfer(receiver, assets);
    }

    /// @dev Sets waToken's allowance for gateway's aTokens to `type(uint256).max` if it falls below `amount`
    function _ensureWrapperAllowance(uint256 amount) internal {
        if (aToken.allowance(address(this), address(waToken)) < amount) {
            aToken.approve(address(waToken), type(uint256).max);
        }
    }
}
