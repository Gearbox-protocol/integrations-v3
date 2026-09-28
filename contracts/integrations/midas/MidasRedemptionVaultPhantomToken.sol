// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PhantomERC20} from "../common/PhantomERC20.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";
import {IMidasGateway} from "./interfaces/IMidasGateway.sol";

/// @title Midas Redemption Vault phantom token
/// @notice Phantom ERC-20 token that represents expected redemption amounts for a gateway's quote token
contract MidasRedemptionVaultPhantomToken is PhantomERC20, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::MIDAS_REDEMPTION";

    uint256 public constant override version = 3_11;

    address public immutable gateway;

    /// @notice Constructor
    /// @param _gateway The gateway where redemptions are tracked
    /// @param _mToken The Midas token being redeemed
    /// @param _quoteToken The quote token this phantom token tracks
    constructor(address _gateway, address _mToken, address _quoteToken)
        PhantomERC20(
            _quoteToken,
            string.concat(IERC20Metadata(_mToken).symbol(), " redeemed to ", IERC20Metadata(_quoteToken).name()),
            string.concat(IERC20Metadata(_mToken).symbol(), "rd", IERC20Metadata(_quoteToken).symbol()),
            IERC20Metadata(_quoteToken).decimals()
        )
    {
        gateway = _gateway;
    }

    /// @notice Returns the expected amount of quote token from pending redemptions
    /// @param account The account for which the calculation is performed
    /// @return Expected amount of tokenOut that can be withdrawn
    function balanceOf(address account) public view override returns (uint256) {
        (uint256 pendingAmount, uint256 claimableAmount) =
            IMidasGateway(gateway).pendingAndClaimableTokenOutAmounts(account);

        return pendingAmount + claimableAmount;
    }

    /// @notice Returns phantom token's target contract and underlying
    /// @return gateway Gateway contract address
    /// @return underlying Underlying token address (quote token)
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (gateway, underlying);
    }

    /// @notice Serialized phantom token parameters
    /// @return Encoded gateway and underlying token addresses
    function serialize() external view override returns (bytes memory) {
        return abi.encode(gateway, underlying);
    }
}
