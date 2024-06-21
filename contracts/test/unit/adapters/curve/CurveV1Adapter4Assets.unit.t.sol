// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {CurveV1Adapter4Assets} from "../../../../adapters/curve/CurveV1_4.sol";
import {ICurvePool4Assets} from "../../../../integrations/curve/ICurvePool_4.sol";
import {PoolMock, PoolType} from "../../../mocks/integrations/curve/PoolMock.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Curve v1 adapter 4 assets unit test
/// @notice U:[CRV4]: Unit tests for Curve 4 coins pool adapter
contract CurveV1Adapter4AssetsUnitTest is AdapterUnitTestHelper {
    CurveV1Adapter4Assets adapter;
    PoolMock curvePool;

    address token0;
    address token1;
    address token2;
    address token3;
    address lpToken;

    uint256 token0Mask;
    uint256 token1Mask;
    uint256 token2Mask;
    uint256 token3Mask;
    uint256 lpTokenMask;

    function setUp() public {
        _setUp();

        (token0, token0Mask) = (tokens[0], 1);
        (token1, token1Mask) = (tokens[1], 2);
        (token2, token2Mask) = (tokens[2], 4);
        (token3, token3Mask) = (tokens[3], 8);
        (lpToken, lpTokenMask) = (tokens[4], 16);

        address[] memory coins = new address[](4);
        coins[0] = token0;
        coins[1] = token1;
        coins[2] = token2;
        coins[3] = token3;
        curvePool = new PoolMock(PoolType.Stable, coins, new address[](0));

        adapter = new CurveV1Adapter4Assets(address(creditManager), address(curvePool), lpToken, address(0));

        assertEq(adapter.nCoins(), 4, "Incorrect nCoins");
    }

    /// @notice U:[CRV4-1]: Wrapper functions revert on wrong caller
    function test_U_CRV4_01_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.add_liquidity([uint256(0), 0, 0, 0], 0);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity(0, [uint256(0), 0, 0, 0]);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity_imbalance([uint256(0), 0, 0, 0], 0);
    }

    /// @notice U:[CRV4-2]: `add_liquidity` works as expected
    function test_U_CRV4_02_add_liquidity_works_as_expected() public {
        address[] memory tokensToApprove = new address[](4);
        tokensToApprove[0] = token0;
        tokensToApprove[1] = token1;
        tokensToApprove[2] = token2;
        tokensToApprove[3] = token3;
        _executesCall({
            tokensToApprove: tokensToApprove,
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePool4Assets.add_liquidity, ([uint256(750), 500, 500, 250], 500))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.add_liquidity([uint256(750), 500, 500, 250], 500);

        assertEq(tokensToEnable, lpTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CRV4-3]: `remove_liquidity` works as expected
    function test_U_CRV4_03_remove_liquidity_works_as_expected() public {
        _executesCall({
            tokensToApprove: new address[](0),
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePool4Assets.remove_liquidity, (500, [uint256(750), 500, 500, 250]))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.remove_liquidity(500, [uint256(750), 500, 500, 250]);

        assertEq(tokensToEnable, token0Mask | token1Mask | token2Mask | token3Mask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CRV4-4]: `remove_liquidity_imbalance` works as expected
    function test_U_CRV4_04_remove_liquidity_imbalance_works_as_expected() public {
        _executesCall({
            tokensToApprove: new address[](0),
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePool4Assets.remove_liquidity_imbalance, ([uint256(0), 500, 0, 250], 500))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.remove_liquidity_imbalance([uint256(0), 500, 0, 250], 500);

        assertEq(tokensToEnable, token1Mask | token3Mask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }
}
