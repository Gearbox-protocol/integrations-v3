// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PhantomERC20} from "../common/PhantomERC20.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";
import {ITreehouseRedemptionGateway} from "./interfaces/ITreehouseRedemptionGateway.sol";

/// @title Treehouse Redemption phantom token
/// @notice Phantom ERC-20 token that represents expected redemption amounts for a gateway's quote token
contract TreehouseRedemptionPhantomToken is PhantomERC20, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::TREEHOUSE_RD";

    uint256 public constant override version = 3_10;

    address public immutable gateway;

    /// @notice Constructor
    /// @param _gateway The gateway where redemptions are tracked
    /// @param _tAsset The Treehouse asset being redeemed
    /// @param _vaultUnderlying The underlying token redeemed into
    constructor(address _gateway, address _tAsset, address _vaultUnderlying)
        PhantomERC20(
            _vaultUnderlying,
            string.concat(IERC20Metadata(_tAsset).symbol(), " redeemed to ", IERC20Metadata(_vaultUnderlying).name()),
            string.concat(IERC20Metadata(_tAsset).symbol(), "rd", IERC20Metadata(_vaultUnderlying).symbol()),
            IERC20Metadata(_vaultUnderlying).decimals()
        )
    {
        gateway = _gateway;
    }

    /// @notice Returns the expected amount of quote token from pending redemptions
    /// @param account The account for which the calculation is performed
    /// @return Expected amount of tokenOut that can be withdrawn
    function balanceOf(address account) public view override returns (uint256) {
        (uint256 pendingAmount, uint256 claimableAmount) =
            ITreehouseRedemptionGateway(gateway).pendingAndClaimableAmounts(account);

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
