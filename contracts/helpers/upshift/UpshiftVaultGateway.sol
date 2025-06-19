// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IVersion} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IVersion.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
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

contract UpshiftVaultGateway is IUpshiftVaultGateway {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 public constant override contractType = "GATEWAY::UPSHIFT_VAULT_GATEWAY";
    uint256 public constant override version = 3_10;

    address public immutable uptbtcVault;

    address public immutable tbtc;

    mapping(address => PendingRedeem) public pendingRedeems;

    constructor(address _uptbtcVault) {
        uptbtcVault = _uptbtcVault;
        tbtc = IERC4626(_uptbtcVault).asset();
    }

    function deposit(uint256 assets, address receiver) external {
        IERC20(tbtc).safeTransferFrom(msg.sender, address(this), assets);
        IERC20(tbtc).forceApprove(uptbtcVault, assets);
        IERC4626(uptbtcVault).deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) external {
        uint256 amount = IERC4626(uptbtcVault).previewMint(shares);

        IERC20(tbtc).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(tbtc).forceApprove(uptbtcVault, amount);
        IERC4626(uptbtcVault).mint(shares, receiver);
    }

    function requestRedeem(uint256 shares) external {
        if (pendingRedeems[msg.sender].assets > 0) {
            revert("UpshiftVaultGateway: user has a pending redeem");
        }

        IERC20(uptbtcVault).safeTransferFrom(msg.sender, address(this), shares);
        IERC20(uptbtcVault).forceApprove(uptbtcVault, shares);

        (uint256 year, uint256 month, uint256 day, uint256 claimableTimestamp) =
            IUpshiftVault(uptbtcVault).getWithdrawalEpoch();

        uint256 assets = IERC4626(uptbtcVault).previewRedeem(shares);

        pendingRedeems[msg.sender] =
            PendingRedeem({claimableTimestamp: claimableTimestamp, assets: assets, year: year, month: month, day: day});

        IUpshiftVault(uptbtcVault).requestRedeem(shares, address(this), address(this));
    }

    function claim(uint256 amount) external {
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

        uint256 totalClaimableAssets = IUpshiftVault(uptbtcVault).getClaimableAmountByReceiver(
            pendingRedeem.year, pendingRedeem.month, pendingRedeem.day, address(this)
        );

        if (totalClaimableAssets > 0) {
            IUpshiftVault(uptbtcVault).claim(pendingRedeem.year, pendingRedeem.month, pendingRedeem.day, address(this));
        }

        pendingRedeems[msg.sender].assets -= amount;

        IERC20(tbtc).safeTransfer(msg.sender, amount);
    }

    function pendingAssetsOf(address holderAddr) external view returns (uint256) {
        return pendingRedeems[holderAddr].assets;
    }

    function asset() external view returns (address) {
        return tbtc;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return IERC4626(uptbtcVault).previewDeposit(assets);
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return IERC4626(uptbtcVault).previewRedeem(shares);
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return IERC4626(uptbtcVault).convertToAssets(shares);
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return IERC4626(uptbtcVault).convertToShares(assets);
    }

    function decimals() external view returns (uint8) {
        return IERC4626(uptbtcVault).decimals();
    }

    function name() external view returns (string memory) {
        return IERC4626(uptbtcVault).name();
    }

    function symbol() external view returns (string memory) {
        return IERC4626(uptbtcVault).symbol();
    }
}
