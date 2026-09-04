// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ITreehouseRedemptionV2, RedemptionInfo, FEE_PRECISION} from "./interfaces/external/ITreehouseRedemptionV2.sol";
import {ITreehouseRedemptionV3} from "./interfaces/external/ITreehouseRedemptionV3.sol";
import {IWstETH} from "./interfaces/external/IWstETH.sol";

/// @title Treehouse redeemer
/// @notice Holds exactly one Treehouse redemption request on behalf of an account
/// @dev Deployed as a minimal clone by the gateway, one per request, so that requests settle and can be
///      transferred independently. All state changes go through the gateway.
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

    /// @notice The Treehouse RedemptionV2 contract
    address public immutable redemptionV2;

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
    /// @param _redemptionV2 Address of the Treehouse RedemptionV2 contract
    /// @param _tAsset Address of the TAsset contract
    /// @param _vaultUnderlying Address of the underlying token of the vault
    constructor(address _redemptionV2, address _tAsset, address _vaultUnderlying) {
        gateway = msg.sender;
        redemptionV2 = _redemptionV2;
        tAsset = _tAsset;
        vaultUnderlying = _vaultUnderlying;
    }

    /// @notice Sets the account for this redeemer
    function setAccount(address _account) external gatewayOnly {
        account = _account;
    }

    function redeem(uint256 shares) external gatewayOnly whenNotAlreadyRedeemed {
        IERC20(tAsset).forceApprove(redemptionV2, shares);
        ITreehouseRedemptionV2(redemptionV2).redeem(shares.toUint96());
        alreadyRedeemed = true;
        _sweepTAsset();
    }

    function finalizeRedeem() external gatewayOnly {
        ITreehouseRedemptionV2(redemptionV2).finalizeRedeem(0);
        IERC20(vaultUnderlying).safeTransfer(account, IERC20(vaultUnderlying).balanceOf(address(this)));
        _sweepTAsset();
    }

    function rescueToken(address token) external gatewayOnly {
        IERC20(token).safeTransfer(account, IERC20(token).balanceOf(address(this)));
    }

    function pendingAmount() external view returns (uint256) {
        if (ITreehouseRedemptionV2(redemptionV2).getRedeemLength(address(this)) == 0) return 0;

        RedemptionInfo memory redemptionInfo = ITreehouseRedemptionV2(redemptionV2).getRedeemInfo(address(this), 0);

        if (block.timestamp >= redemptionInfo.startTime + ITreehouseRedemptionV2(redemptionV2).waitingPeriod()) {
            return 0;
        }

        return _getRedemptionAmount(redemptionInfo);
    }

    function claimableAmount() external view returns (uint256) {
        if (ITreehouseRedemptionV2(redemptionV2).getRedeemLength(address(this)) == 0) return 0;

        RedemptionInfo memory redemptionInfo = ITreehouseRedemptionV2(redemptionV2).getRedeemInfo(address(this), 0);

        if (block.timestamp < redemptionInfo.startTime + ITreehouseRedemptionV2(redemptionV2).waitingPeriod()) {
            return 0;
        }

        return _getRedemptionAmount(redemptionInfo);
    }

    function _getRedemptionAmount(RedemptionInfo memory redemptionInfo) internal view returns (uint256) {
        (uint256 currentAssets, uint256 currentBaseRate) = _getCurrentAssetsAndBaseRate(redemptionInfo.shares);

        uint256 amountWithFee = Math.min(redemptionInfo.assets, currentAssets)
            * Math.min(redemptionInfo.baseRate, currentBaseRate) / Math.max(redemptionInfo.baseRate, currentBaseRate);

        uint256 redemptionFee = ITreehouseRedemptionV2(redemptionV2).redemptionFee();

        return amountWithFee * (FEE_PRECISION - redemptionFee) / FEE_PRECISION;
    }

    function _getRedemptionFee() internal view returns (uint32 redemptionFee) {
        redemptionFee = ITreehouseRedemptionV2(redemptionV2).redemptionFee();

        try ITreehouseRedemptionV3(redemptionV2).treasuryFee() returns (uint32 treasuryFee) {
            redemptionFee += treasuryFee;
        } catch {}
    }

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
