// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";
import {IMidasRedemptionVaultGateway} from "../../interfaces/midas/IMidasRedemptionVaultGateway.sol";

/// @title Midas Redemption Vault phantom token
/// @notice Phantom ERC-20 token that represents expected redemption amounts for a specific output token
contract MidasRedemptionVaultPhantomToken is PhantomERC20, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::MIDAS_REDEMPTION";

    uint256 public constant override version = 3_10;

    address public immutable gateway;

    address public immutable tokenOut;

    /// @notice Constructor
    /// @param _gateway The gateway where redemptions are tracked
    /// @param _tokenOut The specific output token this phantom token tracks
    constructor(address _gateway, address _tokenOut)
        PhantomERC20(
            _tokenOut,
            string.concat(
                IERC20Metadata(IMidasRedemptionVaultGateway(_gateway).mToken()).symbol(),
                " redeemed to ",
                IERC20Metadata(_tokenOut).name()
            ),
            string.concat(
                IERC20Metadata(IMidasRedemptionVaultGateway(_gateway).mToken()).symbol(),
                "rd",
                IERC20Metadata(_tokenOut).symbol()
            ),
            IERC20Metadata(_tokenOut).decimals()
        )
    {
        gateway = _gateway;
        tokenOut = _tokenOut;
    }

    /// @notice Returns the expected amount of tokenOut from pending redemptions
    /// @param account The account for which the calculation is performed
    /// @return Expected amount of tokenOut that can be withdrawn
    function balanceOf(address account) public view override returns (uint256) {
        return IMidasRedemptionVaultGateway(gateway).pendingTokenOutAmount(account, tokenOut);
    }

    /// @notice Returns phantom token's target contract and underlying
    /// @return gateway Gateway contract address
    /// @return underlying Underlying token address (tokenOut)
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (gateway, underlying);
    }

    /// @notice Serialized phantom token parameters
    /// @return Encoded gateway and underlying token addresses
    function serialize() external view override returns (bytes memory) {
        return abi.encode(gateway, underlying);
    }
}
