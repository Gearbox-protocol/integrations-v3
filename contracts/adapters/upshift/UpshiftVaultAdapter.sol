// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {IStateSerializer} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IStateSerializer.sol";
import {ERC4626Adapter} from "../erc4626/ERC4626Adapter.sol";
import {IUpshiftVaultAdapter} from "../../interfaces/upshift/IUpshiftVaultAdapter.sol";
import {IUpshiftVaultGateway} from "../../interfaces/upshift/IUpshiftVaultGateway.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title UpshiftVault adapter
/// @notice Implements logic allowing CAs to interact with the UpshiftVault vault, accounting for delayed withdrawals
contract UpshiftVaultAdapter is ERC4626Adapter, IUpshiftVaultAdapter {
    uint256 public constant override(ERC4626Adapter, IVersion) version = 3_10;
    bytes32 public constant override(ERC4626Adapter, IVersion) contractType = "ADAPTER::UPSHIFT_VAULT";

    address public immutable stakedPhantomToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _gateway UpshiftVault gateway address
    /// @param _stakedPhantomToken Staked phantom token address
    constructor(address _creditManager, address _gateway, address _stakedPhantomToken)
        ERC4626Adapter(_creditManager, IUpshiftVaultGateway(_gateway).upshiftVault(), _gateway)
    {
        stakedPhantomToken = _stakedPhantomToken;
        _getMaskOrRevert(stakedPhantomToken);
    }

    /// @dev This always reverts, since neither the original vault nor the gateway support this function
    function _withdraw(address, uint256) internal pure override returns (bool) {
        revert NotImplementedException();
    }

    /// @dev This always reverts, since neither the original vault nor the gateway support this function
    function _redeem(address, uint256) internal pure override returns (bool) {
        revert NotImplementedException();
    }

    /// @notice Requests a redemption from the UpshiftVault vault through the gateway
    /// @param shares Amount of shares to redeem
    /// @dev This function does not accept `receiverAddr` and `holderAddr` parameters,
    ///      since the gateway function only operates on msg.sender
    function requestRedeem(uint256 shares) external override creditFacadeOnly returns (bool) {
        _requestRedeem(shares);
        return true;
    }

    /// @notice Requests a redemption from the UpshiftVault vault through the gateway, with a specified leftover amount
    /// @param leftoverAmount Amount of shares to keep on the account
    function requestRedeemDiff(uint256 leftoverAmount) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();

        uint256 amount = IERC20(vault).balanceOf(creditAccount);
        if (amount <= leftoverAmount) return false;

        unchecked {
            amount -= leftoverAmount;
        }

        _requestRedeem(amount);
        return true;
    }

    /// @dev Internal implementation of `requestRedeem`.
    function _requestRedeem(uint256 shares) internal {
        _executeSwapSafeApprove(vault, abi.encodeCall(IUpshiftVaultGateway.requestRedeem, (shares)));
    }

    /// @notice Claims a redemption from the UpshiftVault vault through the gateway
    /// @dev This function does not accept `receiverAddr` and date parameters,
    ///      since the gateway only processes a single redemption at a time.
    ///      However, it allows to specify an amount, to support partial liquidations.
    function claim(uint256 amount) external override creditFacadeOnly returns (bool) {
        _claim(amount);
        return false;
    }

    /// @dev Internal implementation of `claim`.
    function _claim(uint256 amount) internal {
        _execute(abi.encodeCall(IUpshiftVaultGateway.claim, (amount)));
    }

    /// @notice Claims mature withdrawals, represented by the phantom token
    function withdrawPhantomToken(address token, uint256 amount) external override creditFacadeOnly returns (bool) {
        if (token != stakedPhantomToken) revert IncorrectStakedPhantomTokenException();
        _claim(amount);
        return false;
    }

    /// @dev It's not possible to deposit from underlying (the vault's asset) into the withdrawal phantom token,
    ///      hence the function is not implemented.
    function depositPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    function serialize()
        external
        view
        virtual
        override(ERC4626Adapter, IStateSerializer)
        returns (bytes memory serializedData)
    {
        serializedData = abi.encode(creditManager, targetContract, vault, asset, stakedPhantomToken);
    }
}
