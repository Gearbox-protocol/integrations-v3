// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PhantomERC20} from "../common/PhantomERC20.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";
import {IMidasDepositGateway} from "./interfaces/IMidasDepositGateway.sol";

/// @title Midas Deposit Vault phantom token
/// @notice Phantom ERC-20 token that represents expected deposit amounts for a gateway's mToken
contract MidasDepositVaultPhantomToken is PhantomERC20, IPhantomToken {
    bytes32 public constant override contractType = "PHANTOM_TOKEN::MIDAS_DEPOSIT";

    uint256 public constant override version = 3_10;

    address public immutable gateway;

    /// @notice Constructor
    /// @param _gateway The gateway where deposits are tracked
    /// @param _mToken The Midas token being minted
    /// @param _tokenIn The payment token deposited into Midas
    constructor(address _gateway, address _mToken, address _tokenIn)
        PhantomERC20(
            _mToken,
            string.concat(IERC20Metadata(_tokenIn).symbol(), " deposited to ", IERC20Metadata(_mToken).name()),
            string.concat(IERC20Metadata(_tokenIn).symbol(), "dp", IERC20Metadata(_mToken).symbol()),
            IERC20Metadata(_mToken).decimals()
        )
    {
        gateway = _gateway;
    }

    /// @notice Returns the expected amount of mToken from pending deposits
    /// @param account The account for which the calculation is performed
    /// @return Expected amount of mToken that can be withdrawn
    function balanceOf(address account) public view override returns (uint256) {
        (uint256 pendingAmount, uint256 claimableAmount) =
            IMidasDepositGateway(gateway).pendingAndClaimableTokenOutAmounts(account);

        return pendingAmount + claimableAmount;
    }

    /// @notice Returns phantom token's target contract and underlying
    /// @return gateway Gateway contract address
    /// @return underlying Underlying token address (mToken)
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (gateway, underlying);
    }

    /// @notice Serialized phantom token parameters
    /// @return Encoded gateway and underlying token addresses
    function serialize() external view override returns (bytes memory) {
        return abi.encode(gateway, underlying);
    }
}
