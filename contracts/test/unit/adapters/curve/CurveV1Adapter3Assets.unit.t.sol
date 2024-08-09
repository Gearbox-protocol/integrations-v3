// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

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

    function setUp() public {
        _setUp();

        token0 = tokens[0];
        token1 = tokens[1];
        token2 = tokens[2];
        lpToken = tokens[3];

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
            callData: abi.encodeCall(ICurvePool3Assets.add_liquidity, ([uint256(750), 500, 250], 500))
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.add_liquidity([uint256(750), 500, 250], 500);
        assertTrue(useSafePrices);
    }

    /// @notice U:[CRV3-3]: `remove_liquidity` works as expected
    function test_U_CRV3_03_remove_liquidity_works_as_expected() public {
        _executesCall({
            tokensToApprove: new address[](0),
            callData: abi.encodeCall(ICurvePool3Assets.remove_liquidity, (500, [uint256(750), 500, 250]))
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.remove_liquidity(500, [uint256(750), 500, 250]);
        assertTrue(useSafePrices);
    }

    /// @notice U:[CRV3-4]: `remove_liquidity_imbalance` works as expected
    function test_U_CRV3_04_remove_liquidity_imbalance_works_as_expected() public {
        _executesCall({
            tokensToApprove: new address[](0),
            callData: abi.encodeCall(ICurvePool3Assets.remove_liquidity_imbalance, ([uint256(0), 500, 250], 500))
        });

        vm.prank(creditFacade);
        bool useSafePrices = adapter.remove_liquidity_imbalance([uint256(0), 500, 250], 500);
        assertTrue(useSafePrices);
    }
}
