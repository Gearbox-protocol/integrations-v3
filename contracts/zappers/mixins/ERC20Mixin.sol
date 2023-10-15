// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {ERC20ZapperBase} from "../ERC20ZapperBase.sol";

abstract contract ERC20Mixin is ERC20ZapperBase {
    using SafeERC20 for IERC20;

    function tokenIn() public view override returns (address) {
        return underlying;
    }

    function _previewTokenInToUnderlying(uint256 tokenInAmount) internal pure override returns (uint256 assets) {
        assets = tokenInAmount;
    }

    function _previewUnderlyingToTokenIn(uint256 assets) internal pure override returns (uint256 tokenInAmount) {
        tokenInAmount = assets;
    }

    function _tokenInToUnderlying(uint256 tokenInAmount) internal override returns (uint256 assets) {
        IERC20(tokenIn()).safeTransferFrom(msg.sender, address(this), tokenInAmount);
        assets = tokenInAmount;
    }

    function _underlyingToTokenIn(uint256 assets, address receiver) internal override returns (uint256 tokenInAmount) {
        tokenInAmount = assets;
        IERC20(tokenIn()).safeTransfer(receiver, tokenInAmount);
    }
}
