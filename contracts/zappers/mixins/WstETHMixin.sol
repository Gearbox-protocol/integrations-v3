// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {IwstETH} from "../../integrations/lido/IwstETH.sol";
import {ERC20ZapperBase} from "../ERC20ZapperBase.sol";

abstract contract WstETHMixin is ERC20ZapperBase {
    using SafeERC20 for IERC20;

    address internal immutable _stETH;

    constructor() {
        _stETH = IwstETH(underlying).stETH();
        _resetAllowance(_stETH, underlying);
    }

    function tokenIn() public view override returns (address) {
        return _stETH;
    }

    function _previewTokenInToUnderlying(uint256 tokenInAmount) internal view override returns (uint256 assets) {
        assets = IwstETH(underlying).getWstETHByStETH(tokenInAmount);
    }

    function _previewUnderlyingToTokenIn(uint256 assets) internal view override returns (uint256 tokenInAmount) {
        tokenInAmount = IwstETH(underlying).getStETHByWstETH(assets);
    }

    function _tokenInToUnderlying(uint256 tokenInAmount) internal override returns (uint256 assets) {
        IERC20(_stETH).safeTransferFrom(msg.sender, address(this), tokenInAmount);
        assets = IwstETH(underlying).wrap(tokenInAmount);
    }

    function _underlyingToTokenIn(uint256 assets, address receiver) internal override returns (uint256 tokenInAmount) {
        tokenInAmount = IwstETH(underlying).unwrap(assets);
        IERC20(_stETH).safeTransfer(receiver, tokenInAmount);
    }
}
