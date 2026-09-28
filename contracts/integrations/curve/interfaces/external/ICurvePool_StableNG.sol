// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {ICurvePool} from "./ICurvePool.sol";

/// @title ICurvePoolStableNG
/// @dev Extends original pool contract with liquidity functions
interface ICurvePoolStableNG is ICurvePool {
    function add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) external;

    function remove_liquidity(uint256 _amount, uint256[] memory min_amounts) external;

    function remove_liquidity_imbalance(uint256[] calldata amounts, uint256 max_burn_amount) external;

    function calc_token_amount(uint256[] calldata _amounts, bool _is_deposit) external view returns (uint256);

    function get_balances() external view returns (uint256[] memory);

    function N_COINS() external view returns (uint256);
}
