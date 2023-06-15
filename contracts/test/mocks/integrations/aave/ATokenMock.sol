// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {IAToken} from "../../../../integrations/aave/IAToken.sol";
import {ILendingPool} from "../../../../integrations/aave/ILendingPool.sol";

/// @title AToken mock
contract ATokenMock is IAToken, ERC20 {
    /// @notice Thrown when caller of an `onlyLendingPool` function is not the lending pool
    error CallerNotLendingPool();

    /// @inheritdoc IAToken
    ILendingPool public immutable override POOL;

    /// @inheritdoc IAToken
    address public immutable override UNDERLYING_ASSET_ADDRESS;

    /// @notice Ensures function can only be called by the lending pool
    modifier onlyLendingPool() {
        if (msg.sender != address(POOL)) {
            revert CallerNotLendingPool();
        }
        _;
    }

    /// @notice Constructor
    /// @param _asset Underlying asset address
    constructor(address _asset)
        ERC20(
            string(abi.encodePacked("Aave interest bearing ", ERC20(_asset).name())),
            string(abi.encodePacked("a", ERC20(_asset).symbol()))
        )
    {
        POOL = ILendingPool(msg.sender);
        UNDERLYING_ASSET_ADDRESS = _asset;
    }

    /// @notice Mints given amount of aTokens to user
    /// @dev Can only be called by the lending pool, which transfers underlying asset to this contract before minting
    function mint(address user, uint256 amount, uint256 index) external onlyLendingPool {
        _mint(user, _divByIndex(amount, index));
    }

    /// @notice Burns given amount of aTokens from the user and transfers underlying asset to the receiver
    /// @dev Can only be called by the lending pool
    function burn(address user, address receiver, uint256 amount, uint256 index) external onlyLendingPool {
        _burn(user, _divByIndex(amount, index));
        IERC20(UNDERLYING_ASSET_ADDRESS).transfer(receiver, amount);
    }

    /// @inheritdoc IERC20Metadata
    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return IERC20Metadata(UNDERLYING_ASSET_ADDRESS).decimals();
    }

    /// @inheritdoc IERC20
    function totalSupply() public view override(ERC20, IERC20) returns (uint256) {
        return _mulByIndex(super.totalSupply(), _index());
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view override(ERC20, IERC20) returns (uint256) {
        return _mulByIndex(super.balanceOf(account), _index());
    }

    /// @inheritdoc ERC20
    function _transfer(address from, address to, uint256 amount) internal override {
        super._transfer(from, to, _divByIndex(amount, _index()));
    }

    /// @dev Returns liquidity index of the reserve
    function _index() private view returns (uint256) {
        return POOL.getReserveNormalizedIncome(UNDERLYING_ASSET_ADDRESS);
    }

    /// @dev Multiplies amount by liquidity index
    /// @dev See `rayMul` in Aave's codebase
    function _mulByIndex(uint256 amount, uint256 index) private pure returns (uint256) {
        return (amount * index + RAY / 2) / RAY;
    }

    /// @dev Divides amount by liquidity index
    /// @dev See `rayDiv` in Aave's codebase
    function _divByIndex(uint256 amount, uint256 index) private pure returns (uint256) {
        return (amount * RAY + index / 2) / index;
    }
}
