// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

interface IMellowRedeemQueueAdapter is IAdapter {
    error InvalidRedeemQueueGatewayException();
    error IncorrectStakedPhantomTokenException();

    function redeem(uint256 shares) external returns (bool);

    function redeemDiff(uint256 leftoverAmount) external returns (bool);

    function claim(uint256 amount) external returns (bool);

    function withdrawPhantomToken(address pt, uint256 amount) external returns (bool);

    function depositPhantomToken(address pt, uint256 amount) external returns (bool);

    function vaultToken() external view returns (address);

    function phantomToken() external view returns (address);
}
