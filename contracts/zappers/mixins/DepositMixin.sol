// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IFarmingPool} from "@1inch/farming/contracts/interfaces/IFarmingPool.sol";
import {ZapperBase} from "../ZapperBase.sol";

abstract contract DepositMixin is ZapperBase {
    function tokenOut() public view override returns (address) {
        return pool;
    }

    function _previewSharesToTokenOut(uint256 shares) internal view override returns (uint256 tokenOutAmount) {}

    function _previewTokenOutToShares(uint256 tokenOutAmount) internal view override returns (uint256 shares) {}

    function _sharesToTokenOut(uint256 shares, address receiver) internal override returns (uint256 tokenOutAmount) {}

    function _tokenOutToShares(uint256 tokenOutAmount, address owner) internal override returns (uint256 shares) {}
}
