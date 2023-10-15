// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {IFarmingPool} from "@1inch/farming/contracts/interfaces/IFarmingPool.sol";
import {ZapperBase} from "../ZapperBase.sol";

abstract contract FarmingMixin is ZapperBase {
    using SafeERC20 for IERC20;

    address internal immutable _farmingPool;

    constructor(address farmingPool) {
        _farmingPool = farmingPool;
        _resetAllowance(pool, farmingPool);
    }

    function tokenOut() public view override returns (address) {
        return _farmingPool;
    }

    function _previewSharesToTokenOut(uint256 shares) internal pure override returns (uint256 tokenOutAmount) {
        tokenOutAmount = shares;
    }

    function _previewTokenOutToShares(uint256 tokenOutAmount) internal pure override returns (uint256 shares) {
        shares = tokenOutAmount;
    }

    function _sharesToTokenOut(uint256 shares, address receiver) internal override returns (uint256 tokenOutAmount) {
        IFarmingPool(_farmingPool).deposit(shares);
        tokenOutAmount = shares;
        IERC20(_farmingPool).safeTransfer(receiver, tokenOutAmount);
    }

    function _tokenOutToShares(uint256 tokenOutAmount, address owner) internal override returns (uint256 shares) {
        IERC20(_farmingPool).safeTransferFrom(owner, address(this), tokenOutAmount);
        IFarmingPool(_farmingPool).withdraw(tokenOutAmount);
        shares = tokenOutAmount;
    }
}
