// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PhantomERC20} from "../PhantomERC20.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";
import {IInfinifiUnwindingGateway} from "../../interfaces/infinifi/IInfinifiUnwindingGateway.sol";

/// @title Infinifi Unwinding phantom token
/// @notice Phantom ERC-20 token that represents the balance of the pending and claimable withdrawals in Infinifi Unwinding Gateway
contract InfinifiUnwindingPhantomToken is PhantomERC20, Ownable, IPhantomToken {
    event SetClaimer(address indexed claimer);

    error SubvaultClaimerMismatchException();

    bytes32 public constant override contractType = "PHANTOM_TOKEN::INFINIFI_UNWIND";

    uint256 public constant override version = 3_10;

    address public immutable infinifiUnwindingGateway;

    /// @notice Constructor
    /// @param _infinifiUnwindingGateway The Infinifi Unwinding Gateway where the pending assets are tracked
    constructor(address _infinifiUnwindingGateway)
        PhantomERC20(
            IInfinifiUnwindingGateway(_infinifiUnwindingGateway).iUSD(),
            "Infinifi Unwinding iUSD",
            "wdiUSD",
            IERC20Metadata(IInfinifiUnwindingGateway(_infinifiUnwindingGateway).iUSD()).decimals()
        )
    {
        infinifiUnwindingGateway = _infinifiUnwindingGateway;
    }

    /// @notice Returns the amount of assets pending/claimable for withdrawal
    /// @param account The account for which the calculation is performed
    function balanceOf(address account) public view returns (uint256 balance) {
        return IInfinifiUnwindingGateway(infinifiUnwindingGateway).getPendingAssets(account);
    }

    /// @notice Returns phantom token's target contract and underlying
    function getPhantomTokenInfo() external view override returns (address, address) {
        return (infinifiUnwindingGateway, underlying);
    }

    function serialize() external view override returns (bytes memory) {
        return abi.encode(infinifiUnwindingGateway, underlying);
    }
}
