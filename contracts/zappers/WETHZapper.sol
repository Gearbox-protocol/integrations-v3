// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IWETH} from "@gearbox-protocol/core-v2/contracts/interfaces/external/IWETH.sol";
import {ReceiveIsNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {IWETHZapper, ETH_ADDRESS} from "../interfaces/zappers/IWETHZapper.sol";
import {ZapperBase} from "./ZapperBase.sol";

/// @title WETH zapper
/// @notice Allows users to deposit/withdraw pure ETH to/from a WETH pool in a single operation
contract WETHZapper is ZapperBase, IWETHZapper {
    using Address for address payable;

    /// @notice Special address that corresponds to pure ETH
    address public constant override unwrappedToken = ETH_ADDRESS;

    /// @notice Constructor
    /// @param pool_ Pool to connect this zapper to
    constructor(address pool_) ZapperBase(pool_) {}

    /// @notice Allows this contract to unwrap WETH and forbids other direct ETH transfers
    receive() external payable {
        if (msg.sender != wrappedToken) revert ReceiveIsNotAllowedException();
    }

    /// @notice Zaps wrapping ETH and depositing it to the pool into a single operation
    function deposit(address receiver) external payable override returns (uint256 shares) {
        shares = _deposit(msg.value, receiver);
    }

    /// @notice Same as `deposit` but allows to specify the referral code
    function depositWithReferral(address receiver, uint16 referralCode)
        external
        payable
        override
        returns (uint256 shares)
    {
        shares = _depositWithReferral(msg.value, receiver, referralCode);
    }

    /// @dev Wraps ETH
    function _receiveAndWrap(uint256 amount) internal override returns (uint256 wrappedAmount) {
        IWETH(wrappedToken).deposit{value: amount}();
        return amount;
    }

    /// @dev Unwraps WETH and sends it to `receiver`
    function _unwrapAndSend(uint256 amount, address receiver) internal override returns (uint256 unwrappedAmount) {
        IWETH(wrappedToken).withdraw(amount);
        payable(receiver).sendValue(amount);
        return amount;
    }

    /// @dev Returns amount of WETH one would receive for wrapping `amount` of ETH
    function _previewWrap(uint256 amount) internal pure override returns (uint256 wrappedAmount) {
        return amount;
    }

    /// @dev Returns amount of ETH one would receive for unwrapping `amount` of WETH
    function _previewUnwrap(uint256 amount) internal pure override returns (uint256 unwrappedAmount) {
        return amount;
    }

    /// @dev Pool has infinite WETH allowance so this step can be skipped
    function _resetPoolAllowance() internal override {}
}
