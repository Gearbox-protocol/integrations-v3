// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IZapper} from "./IZapper.sol";

interface IWERC20Zapper is IZapper {
    function deposit(uint256 amount, address receiver) external returns (uint256 shares);

    function depositWithReferral(uint256 amount, address receiver, uint16 referralCode)
        external
        returns (uint256 shares);
}
