// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IWETH} from "@gearbox-protocol/core-v3/contracts/interfaces/external/IWETH.sol";
import {ReceiveIsNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {ETHZapperBase} from "../ETHZapperBase.sol";
import {ZapperBase} from "../ZapperBase.sol";

/// @title WETH trait
/// @notice Implements tokenIn <-> underlying conversion functions for WETH pool zappers with ETH as input token
abstract contract WETHTrait is ETHZapperBase {
    using Address for address payable;

    /// @notice Allows this contract to unwrap WETH and forbids receiving ETH in other ways
    receive() external payable {
        if (msg.sender != underlying) revert ReceiveIsNotAllowedException();
    }

    /// @inheritdoc ZapperBase
    function _previewTokenInToUnderlying(uint256 tokenInAmount) internal pure override returns (uint256 assets) {
        assets = tokenInAmount;
    }

    /// @inheritdoc ZapperBase
    function _previewUnderlyingToTokenIn(uint256 assets) internal pure override returns (uint256 tokenInAmount) {
        tokenInAmount = assets;
    }

    /// @inheritdoc ZapperBase
    function _tokenInToUnderlying(uint256 tokenInAmount) internal override returns (uint256 assets) {
        IWETH(underlying).deposit{value: tokenInAmount}();
        assets = tokenInAmount;
    }

    /// @inheritdoc ZapperBase
    function _underlyingToTokenIn(uint256 assets, address receiver) internal override returns (uint256 tokenInAmount) {
        tokenInAmount = assets;
        IWETH(underlying).withdraw(tokenInAmount);
        payable(receiver).sendValue(tokenInAmount);
    }
}
