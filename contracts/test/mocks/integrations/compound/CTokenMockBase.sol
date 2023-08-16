// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {ICToken} from "../../../../integrations/compound/ICToken.sol";

uint256 constant MINT_ERROR = 1;
uint256 constant REDEEM_ERROR = 2;
uint256 constant REDEEM_UNDERLYING_ERROR = 3;

/// @title CToken mock base
/// @notice Implements mint/burn logic shared between CErc20 and CEther mocks
/// @dev Uses constant interest rate, must be funded with underlying tokens to pay interest
abstract contract CTokenMockBase is ICToken, ERC20 {
    /// @dev Exchange rate between cToken and underlying as of last interest accrual
    uint256 private exchangeRate;

    /// @dev Constant interest rate
    uint256 private immutable interestRate;

    /// @dev Last interest accrual timestamp
    uint256 private lastUpdate;

    /// @dev Seconds per year
    uint256 private constant YEAR = 365 days;

    constructor(uint256 _initialExchangeRate, uint256 _interestRate, string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {
        exchangeRate = _initialExchangeRate;
        interestRate = _interestRate;
        lastUpdate = block.timestamp;
    }

    /// @notice Accrues interest, updates stored exchange rate
    function accrueInterest() external {
        _accrueInterest();
    }

    /// @inheritdoc IERC20Metadata
    function decimals() public pure override(ERC20, IERC20Metadata) returns (uint8) {
        return 8;
    }

    /// @inheritdoc ICToken
    function exchangeRateCurrent() external override returns (uint256) {
        _accrueInterest();
        return exchangeRateStored();
    }

    /// @inheritdoc ICToken
    function exchangeRateStored() public view override returns (uint256) {
        return exchangeRate;
    }

    /// @dev `mint` implementation
    function _mint(uint256 mintAmount) internal returns (uint256) {
        _accrueInterest();
        _transferIn(msg.sender, mintAmount);
        _mint(msg.sender, mintAmount * WAD / exchangeRate);
        return 0;
    }

    /// @dev `redeem` implementation
    function _redeem(uint256 redeemTokens) internal returns (uint256) {
        _accrueInterest();
        _burn(msg.sender, redeemTokens);
        _transferOut(msg.sender, redeemTokens * exchangeRate / WAD);
        return 0;
    }

    /// @dev `_redeemUnderlying` implementation
    function _redeemUnderlying(uint256 redeemAmount) internal returns (uint256) {
        _accrueInterest();
        _burn(msg.sender, redeemAmount * WAD / exchangeRate);
        _transferOut(msg.sender, redeemAmount);
        return 0;
    }

    /// @dev Transfers `amount` of underlying from `from` to this contract
    function _transferIn(address from, uint256 amount) internal virtual;

    /// @dev Transfers `amount` of underlying to `to`
    function _transferOut(address to, uint256 amount) internal virtual;

    /// @dev Updates interest rate accumulator
    function _accrueInterest() private {
        uint256 timeDiff = block.timestamp - lastUpdate;
        if (timeDiff == 0) return;
        exchangeRate = exchangeRate * (WAD + interestRate * timeDiff / YEAR) / WAD;
        lastUpdate = block.timestamp;
    }
}
