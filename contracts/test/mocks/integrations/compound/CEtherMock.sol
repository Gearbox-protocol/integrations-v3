// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {ICEther} from "../../../../integrations/compound/ICEther.sol";

import {CTokenMockBase, REDEEM_ERROR, REDEEM_UNDERLYING_ERROR} from "./CTokenMockBase.sol";

/// @title CEther mock
contract CEtherMock is ICEther, CTokenMockBase {
    using Address for address payable;

    /// @dev If true, all operations will return non-zero error code
    bool public failing;

    constructor(uint256 _initialExchangeRate, uint256 _interestRate)
        CTokenMockBase(_initialExchangeRate, _interestRate, "Compound Ether", "cETH")
    {}

    /// @notice Sets `failing` flag
    function setFailing(bool status) external {
        failing = status;
    }

    /// @inheritdoc ICEther
    function mint() external payable override {
        if (failing) revert("mint failed");
        _mint(msg.value);
    }

    /// @inheritdoc ICEther
    function redeem(uint256 redeemTokens) external override returns (uint256) {
        if (failing) return REDEEM_ERROR;
        return _redeem(redeemTokens);
    }

    /// @inheritdoc ICEther
    function redeemUnderlying(uint256 redeemAmount) external override returns (uint256) {
        if (failing) return REDEEM_UNDERLYING_ERROR;
        return _redeemUnderlying(redeemAmount);
    }

    function _transferIn(address from, uint256 amount) internal override {
        require(msg.sender == from && msg.value == amount);
    }

    function _transferOut(address to, uint256 amount) internal override {
        payable(to).sendValue(amount);
    }
}
