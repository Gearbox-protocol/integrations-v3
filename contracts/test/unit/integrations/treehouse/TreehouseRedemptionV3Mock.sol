// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {
    RedemptionInfo,
    FEE_PRECISION
} from "../../../../integrations/treehouse/interfaces/external/ITreehouseRedemptionV3.sol";
import {ITreehouseVault} from "../../../../integrations/treehouse/interfaces/external/ITreehouseVault.sol";

contract TreehouseVaultMock {
    address public immutable underlying;

    constructor(address underlying_) {
        underlying = underlying_;
    }

    function getUnderlying() external view returns (address) {
        return underlying;
    }
}

/// @dev Minimal Treehouse RedemptionV3 stand-in: pulls tAsset on `redeem` and pays vault underlying on
///      `finalizeRedeem` (after fees), mirroring the production settlement path used by `TreehouseRedeemer`.
contract TreehouseRedemptionV3Mock {
    using SafeERC20 for IERC20;

    address public TASSET;
    address public VAULT;
    address public vaultUnderlying;

    uint32 public redemptionFee = 100;
    uint32 public treasuryFee = 50;
    uint32 public waitingPeriod = 1 days;

    mapping(address => RedemptionInfo[]) internal _redeems;

    constructor(address tAsset_, address vault_) {
        TASSET = tAsset_;
        VAULT = vault_;
        vaultUnderlying = ITreehouseVault(vault_).getUnderlying();
    }

    function setFees(uint32 redemptionFee_, uint32 treasuryFee_) external {
        redemptionFee = redemptionFee_;
        treasuryFee = treasuryFee_;
    }

    function setWaitingPeriod(uint32 waitingPeriod_) external {
        waitingPeriod = waitingPeriod_;
    }

    function redeem(uint96 shares) external {
        IERC20(TASSET).safeTransferFrom(msg.sender, address(this), shares);
        _redeems[msg.sender].push(
            RedemptionInfo({
                startTime: uint64(block.timestamp), shares: shares, assets: uint128(shares), baseRate: 1e18
            })
        );
    }

    function finalizeRedeem(uint256 index) external {
        RedemptionInfo[] storage userRedeems = _redeems[msg.sender];
        require(index < userRedeems.length, "NO_REDEEM");

        RedemptionInfo memory info = userRedeems[index];
        uint256 last = userRedeems.length - 1;
        if (index != last) userRedeems[index] = userRedeems[last];
        userRedeems.pop();

        IERC20(vaultUnderlying).safeTransfer(msg.sender, _payoutAmount(info.assets));
    }

    function getRedeemLength(address user) external view returns (uint256) {
        return _redeems[user].length;
    }

    function getRedeemInfo(address user, uint256 index) external view returns (RedemptionInfo memory) {
        return _redeems[user][index];
    }

    function _payoutAmount(uint256 assets) internal view returns (uint256) {
        return assets * (FEE_PRECISION - redemptionFee - treasuryFee) / FEE_PRECISION;
    }
}
