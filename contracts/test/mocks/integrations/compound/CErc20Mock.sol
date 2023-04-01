// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ICErc20, ICErc20Actions} from "../../../../integrations/compound/ICErc20.sol";

import {CTokenMockBase, MINT_ERROR, REDEEM_ERROR, REDEEM_UNDERLYING_ERROR} from "./CTokenMockBase.sol";

/// @title CErc20 mock
contract CErc20Mock is ICErc20, CTokenMockBase {
    /// @dev If true, all operations will return non-zero error code
    bool public failing;

    /// @inheritdoc ICErc20
    address public immutable override underlying;

    constructor(address _underlying, uint256 _initialExchangeRate, uint256 _interestRate)
        CTokenMockBase(
            _initialExchangeRate,
            _interestRate,
            string(abi.encodePacked("Compound ", ERC20(_underlying).name())),
            string(abi.encodePacked("c", ERC20(_underlying).symbol()))
        )
    {
        underlying = _underlying;
    }

    /// @notice Sets `failing` flag
    function setFailing(bool status) external {
        failing = status;
    }

    /// @inheritdoc ICErc20Actions
    function mint(uint256 mintAmount) external override returns (uint256) {
        if (failing) return MINT_ERROR;
        return _mint(mintAmount);
    }

    /// @inheritdoc ICErc20Actions
    function redeem(uint256 redeemTokens) external override returns (uint256) {
        if (failing) return REDEEM_ERROR;
        return _redeem(redeemTokens);
    }

    /// @inheritdoc ICErc20Actions
    function redeemUnderlying(uint256 redeemAmount) external override returns (uint256) {
        if (failing) return REDEEM_UNDERLYING_ERROR;
        return _redeemUnderlying(redeemAmount);
    }

    function _transferIn(address from, uint256 amount) internal override {
        ERC20(underlying).transferFrom(from, address(this), amount);
    }

    function _transferOut(address to, uint256 amount) internal override {
        ERC20(underlying).transfer(to, amount);
    }
}
