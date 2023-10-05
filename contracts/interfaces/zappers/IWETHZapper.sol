// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IZapper} from "./IZapper.sol";

/// @dev Special address that denotes pure ETH
address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

interface IWETHZapper is IZapper {
    function deposit(address receiver) external payable returns (uint256 shares);

    function depositWithReferral(address receiver, uint256 referralCode) external payable returns (uint256 shares);
}
