// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {CurveV1Adapter3Assets} from "../../../../adapters/curve/CurveV1_3.sol";
import {ICurvePool3Assets} from "../../../../integrations/curve/ICurvePool_3.sol";
import {PoolMock, PoolType} from "../../../mocks/integrations/curve/PoolMock.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";

/// @title Curve v1 adapter 3 assets unit test
/// @notice U:[CRV3]: Unit tests for Curve 3 coins pool adapter
contract CurveV1Adapter3AssetsUnitTest is AdapterUnitTestHelper {
    CurveV1Adapter3Assets adapter;
    PoolMock curvePool;

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
        curvePool = new PoolMock(PoolType.Stable, coins, new address[](0));

        adapter = new CurveV1Adapter3Assets(address(creditManager), address(curvePool), lpToken, address(0));

        assertEq(adapter.nCoins(), 3, "Incorrect nCoins");
    }

    /// @notice U:[CRV3-1]: Wrapper functions revert on wrong caller
    function test_U_CRV3_01_wrapper_functions_revert_on_wrong_caller() public {
        _revertsOnNonFacadeCaller();
        adapter.add_liquidity([uint256(0), 0, 0], 0);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity(0, [uint256(0), 0, 0]);

        _revertsOnNonFacadeCaller();
        adapter.remove_liquidity_imbalance([uint256(0), 0, 0], 0);
    }

    /// @notice U:[CRV3-2]: `add_liquidity` works as expected
    function test_U_CRV3_02_add_liquidity_works_as_expected() public {
        address[] memory tokensToApprove = new address[](3);
        tokensToApprove[0] = token0;
        tokensToApprove[1] = token1;
        tokensToApprove[2] = token2;
        _executesCall({
            tokensToApprove: tokensToApprove,
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePool3Assets.add_liquidity, ([uint256(750), 500, 250], 500))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.add_liquidity([uint256(750), 500, 250], 500);

        assertEq(tokensToEnable, lpTokenMask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CRV3-3]: `remove_liquidity` works as expected
    function test_U_CRV3_03_remove_liquidity_works_as_expected() public {
        _executesCall({
            tokensToApprove: new address[](0),
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePool3Assets.remove_liquidity, (500, [uint256(750), 500, 250]))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.remove_liquidity(500, [uint256(750), 500, 250]);

        assertEq(tokensToEnable, token0Mask | token1Mask | token2Mask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CRV3-4]: `remove_liquidity_imbalance` works as expected
    function test_U_CRV3_04_remove_liquidity_imbalance_works_as_expected() public {
        _executesCall({
            tokensToApprove: new address[](0),
            tokensToValidate: new address[](0),
            callData: abi.encodeCall(ICurvePool3Assets.remove_liquidity_imbalance, ([uint256(0), 500, 250], 500))
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.remove_liquidity_imbalance([uint256(0), 500, 250], 500);

        assertEq(tokensToEnable, token1Mask | token2Mask, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }
}
