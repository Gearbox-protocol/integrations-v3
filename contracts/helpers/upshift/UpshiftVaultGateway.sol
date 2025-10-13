// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {ReentrancyGuardTrait} from "@gearbox-protocol/core-v3/contracts/traits/ReentrancyGuardTrait.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IUpshiftVault} from "../../integrations/upshift/IUpshiftVault.sol";
import {IUpshiftVaultGateway} from "../../interfaces/upshift/IUpshiftVaultGateway.sol";

struct PendingRedeem {
    uint256 claimableTimestamp;
    uint256 assets;
    uint256 year;
    uint256 month;
    uint256 day;
}

contract UpshiftVaultGateway is ReentrancyGuardTrait, IUpshiftVaultGateway {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "GATEWAY::UPSHIFT_VAULT";
    uint256 public constant override version = 3_10;

    address public immutable upshiftVault;

    address public immutable asset;

    mapping(address => PendingRedeem) public pendingRedeems;

    constructor(address _upshiftVault) {
        upshiftVault = _upshiftVault;
        asset = IERC4626(_upshiftVault).asset();
    }

    function deposit(uint256 assets, address receiver) external nonReentrant {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
        IERC20(asset).forceApprove(upshiftVault, assets);
        IERC4626(upshiftVault).deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) external nonReentrant {
        uint256 amount = IERC4626(upshiftVault).previewMint(shares);

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).forceApprove(upshiftVault, amount);
        IERC4626(upshiftVault).mint(shares, receiver);
    }

    function requestRedeem(uint256 shares) external nonReentrant {
        if (pendingRedeems[msg.sender].assets > 0) {
            revert("UpshiftVaultGateway: user has a pending redeem");
        }

        (uint256 year, uint256 month, uint256 day, uint256 claimableTimestamp) =
            IUpshiftVault(upshiftVault).getWithdrawalEpoch();

        uint256 assets = IERC4626(upshiftVault).previewRedeem(shares);

        pendingRedeems[msg.sender] =
            PendingRedeem({claimableTimestamp: claimableTimestamp, assets: assets, year: year, month: month, day: day});

        IUpshiftVault(upshiftVault).requestRedeem({shares: shares, receiverAddr: address(this), holderAddr: msg.sender});
    }

    function claim(uint256 amount) external nonReentrant {
        PendingRedeem memory pendingRedeem = pendingRedeems[msg.sender];

        if (pendingRedeem.assets == 0) {
            revert("UpshiftVaultGateway: user does not have a pending redeem");
        }

        if (amount > pendingRedeem.assets) {
            revert("UpshiftVaultGateway: amount is greater than the pending redeem");
        }

        if (pendingRedeem.claimableTimestamp > block.timestamp) {
            revert("UpshiftVaultGateway: redeem is not claimable yet");
        }

        uint256 totalClaimableAssets = IUpshiftVault(upshiftVault).getClaimableAmountByReceiver(
            pendingRedeem.year, pendingRedeem.month, pendingRedeem.day, address(this)
        );

        if (totalClaimableAssets > 0) {
            IUpshiftVault(upshiftVault).claim(pendingRedeem.year, pendingRedeem.month, pendingRedeem.day, address(this));
        }

        pendingRedeems[msg.sender].assets -= amount;

        IERC20(asset).safeTransfer(msg.sender, amount);
    }

    function pendingAssetsOf(address holderAddr) external view returns (uint256) {
        return pendingRedeems[holderAddr].assets;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return IERC4626(upshiftVault).previewDeposit(assets);
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return IERC4626(upshiftVault).previewRedeem(shares);
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return IERC4626(upshiftVault).convertToAssets(shares);
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return IERC4626(upshiftVault).convertToShares(assets);
    }

    function decimals() external view returns (uint8) {
        return IERC4626(upshiftVault).decimals();
    }

    function name() external view returns (string memory) {
        return IERC4626(upshiftVault).name();
    }

    function symbol() external view returns (string memory) {
        return IERC4626(upshiftVault).symbol();
    }
}
