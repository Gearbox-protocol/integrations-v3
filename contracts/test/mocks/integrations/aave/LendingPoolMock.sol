// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RAY} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {IAToken} from "../../../../integrations/aave/IAToken.sol";
import {DataTypes} from "../../../../integrations/aave/DataTypes.sol";
import {ILendingPool} from "../../../../integrations/aave/ILendingPool.sol";

import {ATokenMock} from "./ATokenMock.sol";

/// @notice Lending pool reserve data
struct ReserveData {
    address aTokenAddress;
    uint256 liquidityIndex;
    uint256 interestRate;
    uint40 lastUpdate;
}

/// @title Lending pool mock
/// @notice Resembles the original lending pool, but with constant interest rates
///         Also, some liquidity needs to be sent to aToken mocks after their creation
contract LendingPoolMock is ILendingPool, Ownable {
    /// @notice Thrown when trying to perform an operation with a token for which no aToken exists
    error ReserveDoesNotExist();
    /// @notice Thrown when trying to create an aToken for a token for which it already exists
    error ReserveAlreadyExists();

    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    /// @dev Mapping underlying asset address => reserve data
    mapping(address => ReserveData) private _reserves;

    /// @inheritdoc ILendingPool
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16) external override {
        ReserveData storage reserve = _reserves[asset];
        address aToken = reserve.aTokenAddress;
        if (aToken == address(0)) revert ReserveDoesNotExist();

        IERC20(asset).transferFrom(msg.sender, aToken, amount);

        _updateReserve(reserve);
        ATokenMock(aToken).mint(onBehalfOf, amount, reserve.liquidityIndex);
    }

    /// @inheritdoc ILendingPool
    function withdraw(address asset, uint256 amount, address to) external override returns (uint256) {
        ReserveData storage reserve = _reserves[asset];
        address aToken = reserve.aTokenAddress;
        if (aToken == address(0)) revert ReserveDoesNotExist();

        uint256 amountToWithdraw = amount == type(uint256).max ? IAToken(aToken).balanceOf(msg.sender) : amount;

        _updateReserve(reserve);
        ATokenMock(aToken).burn(msg.sender, to, amountToWithdraw, reserve.liquidityIndex);
        return amountToWithdraw;
    }

    /// @inheritdoc ILendingPool
    function getReserveData(address asset) external view override returns (DataTypes.ReserveData memory) {
        ReserveData memory reserve = _reserves[asset];
        if (reserve.aTokenAddress == address(0)) revert ReserveDoesNotExist();
        DataTypes.ReserveData memory data;
        data.aTokenAddress = reserve.aTokenAddress;
        return data;
    }

    /// @inheritdoc ILendingPool
    function getReserveNormalizedIncome(address asset) external view override returns (uint256) {
        ReserveData memory reserve = _reserves[asset];
        if (reserve.aTokenAddress == address(0)) revert ReserveDoesNotExist();
        if (reserve.lastUpdate == uint40(block.timestamp)) return reserve.liquidityIndex;
        return _getReserveIndex(reserve);
    }

    /// @notice Create the reserve for a new asset
    /// @param asset Address of the underlying asset to create the reserve for
    /// @param interestRate Interest rate for the reserve in RAY
    /// @return aToken Address of the new aToken
    function addReserve(address asset, uint256 interestRate) external onlyOwner returns (address aToken) {
        if (_reserves[asset].aTokenAddress != address(0)) revert ReserveAlreadyExists();
        aToken = address(new ATokenMock(asset));
        _reserves[asset] = ReserveData({
            aTokenAddress: aToken,
            liquidityIndex: RAY,
            interestRate: interestRate,
            lastUpdate: uint40(block.timestamp)
        });
    }

    /// @dev Updates reserve's liquidity index and last update timestamp
    function _updateReserve(ReserveData storage reserve) private {
        if (reserve.lastUpdate == uint40(block.timestamp)) return;
        reserve.liquidityIndex = _getReserveIndex(reserve);
        reserve.lastUpdate = uint40(block.timestamp);
    }

    /// @dev Computes actual reserve's liquidity index
    function _getReserveIndex(ReserveData memory reserve) private view returns (uint256) {
        uint256 timeDiff = uint40(block.timestamp) - reserve.lastUpdate;
        return (reserve.liquidityIndex * (RAY + reserve.interestRate * timeDiff / SECONDS_PER_YEAR) + RAY / 2) / RAY;
    }
}
