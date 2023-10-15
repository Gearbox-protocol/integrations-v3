// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ZapperBase} from "./ZapperBase.sol";
import {IETHZapper, ETH_ADDRESS} from "../interfaces/zappers/IETHZapper.sol";

abstract contract ETHZapperBase is ZapperBase, IETHZapper {
    function tokenIn() public pure override returns (address) {
        return ETH_ADDRESS;
    }

    function deposit(address receiver) external payable returns (uint256 tokenOutAmount) {
        tokenOutAmount = _deposit(msg.value, receiver);
    }

    function depositWithReferral(address receiver, uint256 referralCode)
        external
        payable
        returns (uint256 tokenOutAmount)
    {
        tokenOutAmount = _depositWithReferral(msg.value, receiver, referralCode);
    }
}
