// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {CurveV1Adapter2Assets} from "../../../../adapters/curve/CurveV1_2.sol";
import {ICurvePool2Assets} from "../../../../integrations/curve/ICurvePool_2.sol";
import {PoolMock, PoolType} from "../../../mocks/integrations/curve/PoolMock.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Curve v1 adapter 2 assets unit test
/// @notice U:[CRV2]: Unit tests for Curve 2 coins pool adapter
contract CurveV1Adapter2AssetsUnitTest is AdapterUnitTestHelper {
    CurveV1Adapter2Assets adapter;
    PoolMock curvePool;

    address token0;
    address token1;
    address lpToken;

    uint256 token0Mask;
    uint256 token1Mask;
    uint256 lpTokenMask;

    function setUp() public {
        _setUp();

        (token0, token0Mask) = (tokens[0], 1);
        (token1, token1Mask) = (tokens[1], 2);
        (lpToken, lpTokenMask) = (tokens[2], 4);

        address[] memory coins = new address[](2);
        coins[0] = token0;
        coins[1] = token1;
        curvePool = new PoolMock(PoolType.Stable, coins, new address[](0));

        adapter = new CurveV1Adapter2Assets(address(creditManager), address(curvePool), lpToken, address(0));

        assertEq(adapter.nCoins(), 2, "Incorrect nCoins");
    }

    /// @notice U:[CRV2-1]: Wrapper functions revert on wrong caller
    function test_U_CRV2_01_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.add_liquidity([uint256(0), 0], 0);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity(0, [uint256(0), 0]);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity_imbalance([uint256(0), 0], 0);
    }

    /// @notice U:[CRV2-2]: `add_liquidity` works as expected
    function test_U_CRV2_02_add_liquidity_works_as_expected() public {
        address[] memory tokensToApprove = new address[](2);
        tokensToApprove[0] = token0;
        tokensToApprove[1] = token1;
        _executesCall({
            tokensToApprove: tokensToApprove,
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePool2Assets.add_liquidity, ([uint256(750), 250], 500))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.add_liquidity([uint256(750), 250], 500);

        assertEq(tokensToEnable, lpTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CRV2-3]: `remove_liquidity` works as expected
    function test_U_CRV2_03_remove_liquidity_works_as_expected() public {
        _executesCall({
            tokensToApprove: new address[](0),
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePool2Assets.remove_liquidity, (500, [uint256(750), 250]))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.remove_liquidity(500, [uint256(750), 250]);

        assertEq(tokensToEnable, token0Mask | token1Mask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CRV2-4]: `remove_liquidity_imbalance` works as expected
    function test_U_CRV2_04_remove_liquidity_imbalance_works_as_expected() public {
        _executesCall({
            tokensToApprove: new address[](0),
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePool2Assets.remove_liquidity_imbalance, ([uint256(0), 250], 500))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.remove_liquidity_imbalance([uint256(0), 250], 500);

        assertEq(tokensToEnable, token1Mask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }
}
