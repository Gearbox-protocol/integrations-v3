// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

import {ISecuritizeRedemptionGateway} from "../../interfaces/securitize/ISecuritizeRedemptionGateway.sol";

/// @title Securitize Redemption Phantom token
/// @notice Phantom ERC-20 token that represents the balance of the pending and claimable redeemers in Securitize Redemption Gateway
contract SecuritizeRedemptionPhantomToken is PhantomERC20, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::SECURITIZE_RD";

    uint256 public constant override version = 3_10;

    address public immutable redemptionGateway;

    address public immutable stableCoinToken;

    /// @notice Constructor
    constructor(address _redemptionGateway)
        PhantomERC20(
            ISecuritizeRedemptionGateway(_redemptionGateway).stableCoinToken(),
            string.concat(
                "Securitize pending redemption ",
                IERC20Metadata(ISecuritizeRedemptionGateway(_redemptionGateway).dsToken()).name(),
                " to ",
                IERC20Metadata(ISecuritizeRedemptionGateway(_redemptionGateway).stableCoinToken()).name()
            ),
            string.concat(
                "srp",
                IERC20Metadata(ISecuritizeRedemptionGateway(_redemptionGateway).dsToken()).symbol(),
                "_",
                IERC20Metadata(ISecuritizeRedemptionGateway(_redemptionGateway).stableCoinToken()).symbol()
            ),
            IERC20Metadata(ISecuritizeRedemptionGateway(_redemptionGateway).stableCoinToken()).decimals()
        )
    {
        redemptionGateway = _redemptionGateway;
        stableCoinToken = ISecuritizeRedemptionGateway(_redemptionGateway).stableCoinToken();
    }

    /// @notice Returns the amount of assets pending/claimable for a withdrawal
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view returns (uint256 balance) {
        uint256 stableCoinAmount = ISecuritizeRedemptionGateway(redemptionGateway).getRedemptionAmount(account);
        return stableCoinAmount;
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (redemptionGateway, stableCoinToken);
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(redemptionGateway, stableCoinToken);
    }
}
