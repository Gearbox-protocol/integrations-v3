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
import {IMellowFlexibleDepositGateway} from "../../interfaces/mellow/IMellowFlexibleDepositGateway.sol";
import {WAD} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

uint256 constant PRICE_NUMERATOR = 1e36;

/// @title Mellow Flexible Vaults deposit phantom token
/// @notice Phantom ERC-20 token that represents the balance of the pending and claimable deposits in Mellow Flexible Vaults
contract MellowFlexibleDepositPhantomToken is PhantomERC20, Ownable, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::MELLOW_DEPOSIT";

    uint256 public constant override version = 3_10;

    address public immutable depositQueueGateway;

    address public immutable asset;

    address public immutable mellowRateOracle;

    /// @notice Constructor
    constructor(address _depositQueueGateway, address _mellowRateOracle)
        PhantomERC20(
            IMellowFlexibleDepositGateway(_depositQueueGateway).vaultToken(),
            string.concat(
                "Mellow pending deposit from ",
                IERC20Metadata(IMellowFlexibleDepositGateway(_depositQueueGateway).asset()).name(),
                " to ",
                IERC20Metadata(IMellowFlexibleDepositGateway(_depositQueueGateway).vaultToken()).name()
            ),
            string.concat(
                "mpd",
                IERC20Metadata(IMellowFlexibleDepositGateway(_depositQueueGateway).asset()).symbol(),
                "_",
                IERC20Metadata(IMellowFlexibleDepositGateway(_depositQueueGateway).vaultToken()).symbol()
            ),
            IERC20Metadata(IMellowFlexibleDepositGateway(_depositQueueGateway).vaultToken()).decimals()
        )
    {
        depositQueueGateway = _depositQueueGateway;
        mellowRateOracle = _mellowRateOracle;
        asset = IMellowFlexibleDepositGateway(_depositQueueGateway).asset();
    }

    /// @notice Returns the amount of shares pending/claimable for a deposit
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view returns (uint256 balance) {
        uint256 assetPrice = _getLastAcceptedPrice();

        uint256 pendingAssets = IMellowFlexibleDepositGateway(depositQueueGateway).getPendingAssets(account);

        uint256 claimableShares = IMellowFlexibleDepositGateway(depositQueueGateway).getClaimableShares(account);

        return pendingAssets * assetPrice / WAD + claimableShares;
    }

    /// @notice Retrieves the last non-suspicious report from Mellow's OracleSubmitter for the queue's asset
    function _getLastAcceptedPrice() internal view returns (uint256) {
        uint256 reportNum = IMellowRateOracle(mellowRateOracle).reports(asset);

        for (uint256 i = reportNum; i > 0; i--) {
            OracleReport memory report = IMellowRateOracle(mellowRateOracle).reportAt(asset, i - 1);

            if (!report.isSuspicious || IMellowRateOracle(mellowRateOracle).acceptedAt(asset, i - 1) != 0) {
                return uint256(report.priceD18);
            }
        }

        return 0;
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (depositQueueGateway, underlying);
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(depositQueueGateway, underlying);
    }
}
