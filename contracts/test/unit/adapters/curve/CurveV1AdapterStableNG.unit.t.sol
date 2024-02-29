// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {CurveV1AdapterStableNG} from "../../../../adapters/curve/CurveV1_StableNG.sol";
import {ICurvePoolStableNG} from "../../../../integrations/curve/ICurvePool_StableNG.sol";
import {PoolMock, PoolType} from "../../../mocks/integrations/curve/PoolMock.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Curve Stable NG unit test
/// @notice U:[CRVNG]: Unit tests for Curve StableNG pool adapter
contract CurveV1AdapterStablNGUnitTest is AdapterUnitTestHelper {
    CurveV1AdapterStableNG adapter;
    PoolMock pool;

    address token0;
    address token1;
    address token2;
    address lpToken;

    uint256 token0Mask;
    uint256 token1Mask;
    uint256 token2Mask;
    uint256 lpTokenMask;

    function setUp() public {
        _setUp();

        (token0, token0Mask) = (tokens[0], 1);
        (token1, token1Mask) = (tokens[1], 2);
        (token2, token2Mask) = (tokens[2], 4);
        (lpToken, lpTokenMask) = (tokens[3], 8);

        address[] memory coins = new address[](3);
        coins[0] = token0;
        coins[1] = token1;
        coins[2] = token2;
        pool = new PoolMock(PoolType.Stable, coins, new address[](0));

        adapter = new CurveV1AdapterStableNG(address(creditManager), address(pool), lpToken, address(0));

        assertEq(adapter.nCoins(), 3, "Incorrect nCoins");
    }

    /// @notice U:[CRVNG-1]: Wrapper functions revert on wrong caller
    function test_U_CRVNG_01_wrapper_functions_revert_on_wrong_caller() public {
        uint256[] memory amounts;

        _revertsOnNonFacadeCaller();
        adapter.add_liquidity(amounts, 0);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity(0, amounts);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity_imbalance(amounts, 0);
    }

    /// @notice U:[CRVNG-2]: `add_liquidity` works as expected
    function test_U_CRVNG_02_add_liquidity_works_as_expected() public {
        address[] memory tokensToApprove = new address[](2);
        tokensToApprove[0] = token0;
        tokensToApprove[1] = token1;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 750;
        amounts[1] = 250;
        amounts[2] = 125;

        _executesCall({
            tokensToApprove: tokensToApprove,
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePoolStableNG.add_liquidity, (amounts, 500))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.add_liquidity(amounts, 500);

        assertEq(tokensToEnable, lpTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CRVNG-3]: `remove_liquidity` works as expected
    function test_U_CRVNG_03_remove_liquidity_works_as_expected() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 750;
        amounts[1] = 250;
        amounts[2] = 125;

        _executesCall({
            tokensToApprove: new address[](0),
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePoolStableNG.remove_liquidity, (500, amounts))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.remove_liquidity(500, amounts);

        assertEq(tokensToEnable, token0Mask | token1Mask | token2Mask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CRVNG-4]: `remove_liquidity_imbalance` works as expected
    function test_U_CRVNG_04_remove_liquidity_imbalance_works_as_expected() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 750;
        amounts[1] = 0;
        amounts[2] = 125;

        _executesCall({
            tokensToApprove: new address[](0),
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePoolStableNG.remove_liquidity_imbalance, (amounts, 500))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.remove_liquidity_imbalance(amounts, 500);

        assertEq(tokensToEnable, token0Mask | token2Mask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }
}
