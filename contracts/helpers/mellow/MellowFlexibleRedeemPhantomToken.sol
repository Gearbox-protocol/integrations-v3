// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

import {IMellowRateOracle, OracleReport} from "../../integrations/mellow/IMellowRateOracle.sol";
import {IMellowFlexibleRedeemGateway} from "../../interfaces/mellow/IMellowFlexibleRedeemGateway.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

uint256 constant PRICE_NUMERATOR = 1e36;

/// @title Mellow Flexible Vaults redemption phantom token
/// @notice Phantom ERC-20 token that represents the balance of the pending and claimable redemptions in Mellow Flexible Vaults
contract MellowFlexibleRedeemPhantomToken is PhantomERC20, Ownable, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::MELLOW_REDEEM";

    uint256 public constant override version = 3_10;

    address public immutable redeemQueueGateway;

    address public immutable asset;

    address public immutable mellowRateOracle;

    /// @notice Constructor
    constructor(address _redeemQueueGateway, address _mellowRateOracle)
        PhantomERC20(
            IMellowFlexibleRedeemGateway(_redeemQueueGateway).asset(),
            string.concat(
                "Mellow pending redemption from ",
                IERC20Metadata(IMellowFlexibleRedeemGateway(_redeemQueueGateway).vaultToken()).name(),
                " to ",
                IERC20Metadata(IMellowFlexibleRedeemGateway(_redeemQueueGateway).asset()).name()
            ),
            string.concat(
                "mpr",
                IERC20Metadata(IMellowFlexibleRedeemGateway(_redeemQueueGateway).vaultToken()).symbol(),
                "_",
                IERC20Metadata(IMellowFlexibleRedeemGateway(_redeemQueueGateway).asset()).symbol()
            ),
            IERC20Metadata(IMellowFlexibleRedeemGateway(_redeemQueueGateway).asset()).decimals()
        )
    {
        redeemQueueGateway = _redeemQueueGateway;
        mellowRateOracle = _mellowRateOracle;
        asset = IMellowFlexibleRedeemGateway(_redeemQueueGateway).asset();
    }

    /// @notice Returns the amount of assets pending/claimable for redemption
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view returns (uint256 balance) {
        uint256 sharesRate = _getLastAcceptedRate();

        uint256 pendingShares = IMellowFlexibleRedeemGateway(redeemQueueGateway).getPendingShares(account);

        uint256 claimableAssets = IMellowFlexibleRedeemGateway(redeemQueueGateway).getClaimableAssets(account);

        return pendingShares * sharesRate / WAD + claimableAssets;
    }

    /// @notice Retrieves the last non-suspicious report from Mellow's OracleSubmitter for the queue's asset
    function _getLastAcceptedRate() internal view returns (uint256) {
        uint256 reportNum = IMellowRateOracle(mellowRateOracle).reports(asset);

        for (uint256 i = reportNum; i > 0; i--) {
            OracleReport memory report = IMellowRateOracle(mellowRateOracle).reportAt(asset, i - 1);

            if (!report.isSuspicious || IMellowRateOracle(mellowRateOracle).acceptedAt(asset, i - 1) != 0) {
                return PRICE_NUMERATOR / report.priceD18;
            }
        }

        return 0;
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (redeemQueueGateway, underlying);
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(redeemQueueGateway, underlying);
    }
}
