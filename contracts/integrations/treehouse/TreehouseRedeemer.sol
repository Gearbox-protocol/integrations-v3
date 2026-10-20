// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ITreehouseRedemptionV3, RedemptionInfo, FEE_PRECISION} from "./interfaces/external/ITreehouseRedemptionV3.sol";
import {IWstETH} from "./interfaces/external/IWstETH.sol";

/// @title Treehouse redeemer
/// @notice Holds exactly one Treehouse redemption request on behalf of an account
/// @dev Deployed as a minimal clone by the gateway, one per request, so that requests settle and can be
///      transferred independently. All state changes go through the gateway.
/// @dev The intended target contract is non-updatable, so changes in the redemption behavior
///      are not expected.
contract TreehouseRedeemer {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /// @notice Thrown when attempting to call a function from a caller other than the gateway.
    error CallerNotGatewayException();

    /// @notice Thrown when attempting to redeem from a used redeemer
    error AlreadyRedeemedException();

    /// @notice Thrown when attempting to withdraw more tokens than the redeemer has
    error InsufficientBalanceException();

    /// @notice The account connected to this redeemer
    address public account;

    /// @notice The gateway that is using this redeemer
    address public immutable gateway;

    /// @notice The Treehouse redemptionV3 contract
    address public immutable redemptionV3;

    /// @notice The TAsset contract
    address public immutable tAsset;

    /// @notice The underlying token of the vault
    address public immutable vaultUnderlying;

    /// @notice Whether this redeemer already submitted a redemption request via `redeem`
    bool public alreadyRedeemed;

    modifier whenNotAlreadyRedeemed() {
        if (alreadyRedeemed) revert AlreadyRedeemedException();
        _;
    }

    modifier gatewayOnly() {
        if (msg.sender != gateway) revert CallerNotGatewayException();
        _;
    }

    /// @notice Constructor
    /// @param _redemptionV3 Address of the Treehouse redemptionV3 contract
    /// @param _tAsset Address of the TAsset contract
    /// @param _vaultUnderlying Address of the underlying token of the vault
    constructor(address _redemptionV3, address _tAsset, address _vaultUnderlying) {
        gateway = msg.sender;
        redemptionV3 = _redemptionV3;
        tAsset = _tAsset;
        vaultUnderlying = _vaultUnderlying;
    }

    /// @notice Sets the account for this redeemer
    function setAccount(address _account) external gatewayOnly {
        account = _account;
    }

    /// @notice Redeems shares of TAsset for underlying
    /// @dev Only one redemption is allowed per redeemer
    function redeem(uint256 shares) external gatewayOnly whenNotAlreadyRedeemed {
        IERC20(tAsset).forceApprove(redemptionV3, shares);
        ITreehouseRedemptionV3(redemptionV3).redeem(shares.toUint96());
        alreadyRedeemed = true;
        _sweepTAsset();
    }

    /// @notice Finalizes the redemption and transfers funds to the connected account
    function finalizeRedeem() external gatewayOnly {
        ITreehouseRedemptionV3(redemptionV3).finalizeRedeem(0);
        IERC20(vaultUnderlying).safeTransfer(account, IERC20(vaultUnderlying).balanceOf(address(this)));
        _sweepTAsset();
    }

    /// @notice Rescues any ERC20 tokens left in the redeemer to the connected account
    /// @dev    May be used to rescue any tokens stranded on the redeemer, for example,
    ///         if Treehouse airdrops some rewards on it.
    function rescueToken(address token) external gatewayOnly {
        IERC20(token).safeTransfer(account, IERC20(token).balanceOf(address(this)));
    }

    /// @notice Returns the amount of underlying that is pending redemption
    function pendingAmount() external view returns (uint256) {
        if (ITreehouseRedemptionV3(redemptionV3).getRedeemLength(address(this)) == 0) return 0;

        RedemptionInfo memory redemptionInfo = ITreehouseRedemptionV3(redemptionV3).getRedeemInfo(address(this), 0);

        if (block.timestamp >= redemptionInfo.startTime + ITreehouseRedemptionV3(redemptionV3).waitingPeriod()) {
            return 0;
        }

        return _getRedemptionAmount(redemptionInfo);
    }

    /// @notice Returns the amount of underlying that is claimable
    function claimableAmount() external view returns (uint256) {
        if (ITreehouseRedemptionV3(redemptionV3).getRedeemLength(address(this)) == 0) return 0;

        RedemptionInfo memory redemptionInfo = ITreehouseRedemptionV3(redemptionV3).getRedeemInfo(address(this), 0);

        if (block.timestamp < redemptionInfo.startTime + ITreehouseRedemptionV3(redemptionV3).waitingPeriod()) {
            return 0;
        }

        return _getRedemptionAmount(redemptionInfo);
    }

    /// @dev Computes the amount of underlying that will be returned from an unclaimed redemption
    /// @dev The redemption amount is calculated as
    ///      shares * min(current tAsset rate, initial tAsset rate) * min(wstETH rate, initial wstETH rate) /
    ///      max(initial tAsset rate, initial wstETH rate), to which a fee as also applied. This formula is
    ///      used both in Treehouse code and documentation.
    function _getRedemptionAmount(RedemptionInfo memory redemptionInfo) internal view returns (uint256) {
        (uint256 currentAssets, uint256 currentBaseRate) = _getCurrentAssetsAndBaseRate(redemptionInfo.shares);

        uint256 amountWithFee = Math.min(redemptionInfo.assets, currentAssets)
            * Math.min(redemptionInfo.baseRate, currentBaseRate) / Math.max(redemptionInfo.baseRate, currentBaseRate);

        uint256 redemptionFee = _getRedemptionFee();

        return amountWithFee * (FEE_PRECISION - redemptionFee) / FEE_PRECISION;
    }

    /// @dev Computes the total redemption fee
    /// @dev In TreehouseRedemptionV3, the fee is split into holder and treasury parts.
    function _getRedemptionFee() internal view returns (uint32 redemptionFee) {
        return ITreehouseRedemptionV3(redemptionV3).redemptionFee() + ITreehouseRedemptionV3(redemptionV3).treasuryFee();
    }

    /// @dev Computes the current tAsset rate and underlying (wstETH) rate
    function _getCurrentAssetsAndBaseRate(uint256 shares)
        internal
        view
        returns (uint256 currentAssets, uint256 currentBaseRate)
    {
        currentAssets = IERC4626(tAsset).convertToAssets(shares);
        currentBaseRate = IWstETH(vaultUnderlying).stEthPerToken();
    }

    /// @dev Returns any TAsset left here to the account. A redeemer may have leftover TAsset if Treehouse does not
    ///      consume the whole amount on redemption request, or has some airdrop mechanic. The transfer is optional
    ///      to avoid breaking withdrawals if, e.g., the TAsset is paused.
    function _sweepTAsset() internal {
        uint256 tAssetBalance = IERC20(tAsset).balanceOf(address(this));
        if (tAssetBalance > 0) {
            tAsset.call(abi.encodeCall(IERC20.transfer, (account, tAssetBalance)));
        }
    }
}
