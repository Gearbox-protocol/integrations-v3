// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ZapperBase} from "./ZapperBase.sol";
import {IERC20Zapper} from "../interfaces/zappers/IERC20Zapper.sol";

abstract contract ERC20ZapperBase is ZapperBase, IERC20Zapper {
    function deposit(uint256 tokenInAmount, address receiver) external returns (uint256 tokenOutAmount) {
        tokenOutAmount = _deposit(tokenInAmount, receiver);
    }

    function depositWithReferral(uint256 tokenInAmount, address receiver, uint256 referralCode)
        external
        returns (uint256 tokenOutAmount)
    {
        tokenOutAmount = _depositWithReferral(tokenInAmount, receiver, referralCode);
    }
}
