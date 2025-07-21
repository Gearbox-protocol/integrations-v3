// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {
    IKodiakIslandGatewayAdapter,
    KodiakIslandStatus,
    IslandStatus
} from "../../interfaces/kodiak/IKodiakIslandGatewayAdapter.sol";
import {IKodiakIslandGateway, Ratios} from "../../interfaces/kodiak/IKodiakIslandGateway.sol";
import {IKodiakIsland} from "../../integrations/kodiak/IKodiakIsland.sol";

/// @title KodiakIslandGateway adapter
/// @notice Implements logic for interacting with KodiakIslandGateway contracts
contract KodiakIslandGatewayAdapter is AbstractAdapter, IKodiakIslandGatewayAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::KODIAK_ISLAND_GATEWAY";
    uint256 public constant override version = 3_10;

    EnumerableSet.AddressSet private _allowedIslands;

    mapping(address => IslandStatus) private _islandStatus;

    constructor(address _creditManager, address _kodiakGateway) AbstractAdapter(_creditManager, _kodiakGateway) {}

    // ------------- //
    // ADD LIQUIDITY //
    // ------------- //

    /// @notice Adds liquidity to an island with an imbalanced ratio.
    /// @dev `receiver` is ignored, since it is always set to the credit account.
    function addLiquidityImbalanced(address island, uint256 amount0, uint256 amount1, uint256 minLPAmount, address)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        if (!_isDepositAllowed(island)) revert IslandNotAllowedException(island);

        (address token0, address token1) = _getIslandTokens(island);

        address creditAccount = _creditAccount();

        _addLiquidityImbalanced(island, token0, token1, amount0, amount1, minLPAmount, creditAccount);

        return true;
    }

    /// @notice Adds liquidity to an island with an imbalanced ratio, with externally provided deposit and price ratios.
    /// @dev `receiver` is ignored, since it is always set to the credit account.
    function addLiquidityImbalancedAssisted(
        address island,
        uint256 amount0,
        uint256 amount1,
        uint256 minLPAmount,
        address,
        Ratios memory ratios
    ) external override creditFacadeOnly returns (bool) {
        if (!_isDepositAllowed(island)) revert IslandNotAllowedException(island);

        (address token0, address token1) = _getIslandTokens(island);

        address creditAccount = _creditAccount();

        _addLiquidityImbalancedAssisted(island, token0, token1, amount0, amount1, minLPAmount, creditAccount, ratios);

        return true;
    }

    /// @notice Adds liquidity to an island with an imbalanced ratio, using the entire balance of the tokens,
    ///         except the specified amount.
    function addLiquidityImbalancedDiff(
        address island,
        uint256 leftoverAmount0,
        uint256 leftoverAmount1,
        uint256[2] memory minRatesRAY
    ) external override creditFacadeOnly returns (bool) {
        if (!_isDepositAllowed(island)) revert IslandNotAllowedException(island);

        (address token0, address token1) = _getIslandTokens(island);

        address creditAccount = _creditAccount();

        uint256 amount0 = _getAmountOverLeftover(token0, leftoverAmount0, creditAccount);
        uint256 amount1 = _getAmountOverLeftover(token1, leftoverAmount1, creditAccount);

        if (amount0 == 0 && amount1 == 0) return false;

        uint256 minLPAmount = (amount0 * minRatesRAY[0] + amount1 * minRatesRAY[1]) / RAY;

        _addLiquidityImbalanced(island, token0, token1, amount0, amount1, minLPAmount, creditAccount);

        return true;
    }

    /// @notice Adds liquidity to an island with an imbalanced ratio, using the entire balance of the tokens,
    ///         except the specified amount, with externally provided deposit and price ratios.
    function addLiquidityImbalancedDiffAssisted(
        address island,
        uint256 leftoverAmount0,
        uint256 leftoverAmount1,
        uint256[2] memory minRatesRAY,
        Ratios memory ratios
    ) external override creditFacadeOnly returns (bool) {
        if (!_isDepositAllowed(island)) revert IslandNotAllowedException(island);

        (address token0, address token1) = _getIslandTokens(island);

        address creditAccount = _creditAccount();

        uint256 amount0 = _getAmountOverLeftover(token0, leftoverAmount0, creditAccount);
        uint256 amount1 = _getAmountOverLeftover(token1, leftoverAmount1, creditAccount);

        if (amount0 == 0 && amount1 == 0) return false;

        uint256 minLPAmount = (amount0 * minRatesRAY[0] + amount1 * minRatesRAY[1]) / RAY;

        _addLiquidityImbalancedAssisted(island, token0, token1, amount0, amount1, minLPAmount, creditAccount, ratios);

        return true;
    }

    /// @dev Internal implementation of `addLiquidityImbalanced`.
    function _addLiquidityImbalanced(
        address island,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 minLPAmount,
        address creditAccount
    ) internal {
        _approveToken(token0, type(uint256).max);
        _approveToken(token1, type(uint256).max);
        _execute(
            abi.encodeCall(
                IKodiakIslandGateway.addLiquidityImbalanced, (island, amount0, amount1, minLPAmount, creditAccount)
            )
        );
        _approveToken(token0, 1);
        _approveToken(token1, 1);
    }

    /// @dev Internal implementation of `addLiquidityImbalancedAssisted`.
    function _addLiquidityImbalancedAssisted(
        address island,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 minLPAmount,
        address creditAccount,
        Ratios memory ratios
    ) internal {
        _approveToken(token0, type(uint256).max);
        _approveToken(token1, type(uint256).max);
        _execute(
            abi.encodeCall(
                IKodiakIslandGateway.addLiquidityImbalancedAssisted,
                (island, amount0, amount1, minLPAmount, creditAccount, ratios)
            )
        );
        _approveToken(token0, 1);
        _approveToken(token1, 1);
    }

    // ---------------- //
    // REMOVE LIQUIDITY //
    // ---------------- //

    /// @notice Removes liquidity from an island with an imbalanced ratio.
    /// @dev `receiver` is ignored, since it is always set to the credit account.
    function removeLiquidityImbalanced(
        address island,
        uint256 lpAmount,
        uint256 token0proportion,
        uint256[2] memory minAmounts,
        address
    ) external override creditFacadeOnly returns (bool) {
        if (!_isWithdrawalAllowed(island)) revert IslandNotAllowedException(island);

        address creditAccount = _creditAccount();

        _removeLiquidityImbalanced(island, lpAmount, token0proportion, minAmounts, creditAccount);

        return true;
    }

    /// @notice Removes liquidity from an island with an imbalanced ratio, using the entire island balance,
    ///         except the specified amount.
    function removeLiquidityImbalancedDiff(
        address island,
        uint256 leftoverLPAmount,
        uint256 token0proportion,
        uint256[2] memory minRatesRAY
    ) external override creditFacadeOnly returns (bool) {
        if (!_isWithdrawalAllowed(island)) revert IslandNotAllowedException(island);

        address creditAccount = _creditAccount();

        uint256 lpAmount = _getAmountOverLeftover(island, leftoverLPAmount, creditAccount);

        if (lpAmount == 0) return false;

        uint256[2] memory minAmounts;
        minAmounts[0] = lpAmount * minRatesRAY[0] / RAY;
        minAmounts[1] = lpAmount * minRatesRAY[1] / RAY;

        _removeLiquidityImbalanced(island, lpAmount, token0proportion, minAmounts, creditAccount);

        return true;
    }

    /// @dev Internal implementation of `removeLiquidityImbalanced`.
    function _removeLiquidityImbalanced(
        address island,
        uint256 lpAmount,
        uint256 token0proportion,
        uint256[2] memory minAmounts,
        address creditAccount
    ) internal {
        _approveToken(island, type(uint256).max);
        _execute(
            abi.encodeCall(
                IKodiakIslandGateway.removeLiquidityImbalanced,
                (island, lpAmount, token0proportion, minAmounts, creditAccount)
            )
        );
        _approveToken(island, 1);
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Internal function to get the amount of tokens over the leftover amount.
    function _getAmountOverLeftover(address token, uint256 leftoverAmount, address creditAccount)
        internal
        view
        returns (uint256 amount)
    {
        amount = IERC20(token).balanceOf(creditAccount);
        if (amount > leftoverAmount) {
            amount -= leftoverAmount;
        } else {
            amount = 0;
        }
    }

    /// @dev Internal function to get the island tokens.
    function _getIslandTokens(address island) internal view returns (address token0, address token1) {
        token0 = IKodiakIsland(island).token0();
        token1 = IKodiakIsland(island).token1();
    }

    /// @dev Internal function to check if deposit is allowed for an island.
    function _isDepositAllowed(address island) internal view returns (bool) {
        return _islandStatus[island] == IslandStatus.ALLOWED;
    }

    /// @dev Internal function to check if withdrawal is allowed for an island.
    function _isWithdrawalAllowed(address island) internal view returns (bool) {
        return _islandStatus[island] == IslandStatus.ALLOWED || _islandStatus[island] == IslandStatus.EXIT_ONLY;
    }

    // ---- //
    // DATA //
    // ---- //

    /// @notice Returns the status of a batch of Kodiak islands.
    function allowedIslands() public view returns (KodiakIslandStatus[] memory) {
        address[] memory islands = _allowedIslands.values();

        uint256 len = islands.length;
        KodiakIslandStatus[] memory islandsStatus = new KodiakIslandStatus[](len);
        for (uint256 i; i < len; ++i) {
            islandsStatus[i].island = islands[i];
            islandsStatus[i].status = _islandStatus[islands[i]];
        }
        return islandsStatus;
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, allowedIslands());
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets allowed status for a batch of Kodiak islands
    function setIslandStatusBatch(KodiakIslandStatus[] calldata islands) external override configuratorOnly {
        uint256 len = islands.length;
        for (uint256 i; i < len; ++i) {
            if (islands[i].status == IslandStatus.ALLOWED) {
                (address token0, address token1) = _getIslandTokens(islands[i].island);
                _getMaskOrRevert(token0);
                _getMaskOrRevert(token1);
                _getMaskOrRevert(islands[i].island);
                _allowedIslands.add(islands[i].island);
                _islandStatus[islands[i].island] = IslandStatus.ALLOWED;
            } else if (islands[i].status == IslandStatus.EXIT_ONLY) {
                _islandStatus[islands[i].island] = IslandStatus.EXIT_ONLY;
            } else if (islands[i].status == IslandStatus.NOT_ALLOWED) {
                _allowedIslands.remove(islands[i].island);
                _islandStatus[islands[i].island] = IslandStatus.NOT_ALLOWED;
            }
        }
    }
}
