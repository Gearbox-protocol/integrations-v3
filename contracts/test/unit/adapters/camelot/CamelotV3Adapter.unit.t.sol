// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {ICamelotV3Router} from "../../../../integrations/camelot/ICamelotV3Router.sol";
import {
    ICamelotV3AdapterEvents,
    ICamelotV3AdapterExceptions,
    ICamelotV3AdapterTypes,
    CamelotV3PoolStatus
} from "../../../../interfaces/camelot/ICamelotV3Adapter.sol";
import {AdapterUnitTestHelper} from "../AdapterUnitTestHelper.sol";
import {CamelotV3AdapterHarness} from "./CamelotV3Adapter.harness.sol";

/// @title Camelot v3 adapter unit test
/// @notice U:[CAMV3]: Unit tests for Camelot v3 swap router adapter
contract CamelotV3AdapterUnitTest is
    AdapterUnitTestHelper,
    ICamelotV3AdapterEvents,
    ICamelotV3AdapterExceptions,
    ICamelotV3AdapterTypes
{
    CamelotV3AdapterHarness adapter;

    address router;

    function setUp() public {
        _setUp();

        router = makeAddr("ROUTER");
        adapter = new CamelotV3AdapterHarness(address(creditManager), router);

        _setPoolsStatus(3, 7);
    }

    /// @notice U:[CAMV3-1]: Constructor works as expected
    function test_U_CAMV3_01_constructor_works_as_expected() public {
        assertEq(adapter.creditManager(), address(creditManager), "Incorrect creditManager");
        assertEq(adapter.addressProvider(), address(addressProvider), "Incorrect addressProvider");
        assertEq(adapter.targetContract(), router, "Incorrect targetContract");
    }

    /// @notice U:[CAMV3-2]: Wrapper functions revert on wrong caller
    function test_U_CAMV3_02_wrapper_functions_revert_on_wrong_caller() public {
        ICamelotV3Router.ExactInputSingleParams memory p1;
        _revertsOnNonFacadeCaller();
        adapter.exactInputSingle(p1);

        ExactDiffInputSingleParams memory p2_2;
        _revertsOnNonFacadeCaller();
        adapter.exactDiffInputSingle(p2_2);

        ICamelotV3Router.ExactInputParams memory p3;
        _revertsOnNonFacadeCaller();
        adapter.exactInput(p3);

        ExactDiffInputParams memory p4_2;
        _revertsOnNonFacadeCaller();
        adapter.exactDiffInput(p4_2);

        ICamelotV3Router.ExactOutputSingleParams memory p5;
        _revertsOnNonFacadeCaller();
        adapter.exactOutputSingle(p5);

        ICamelotV3Router.ExactOutputParams memory p6;
        _revertsOnNonFacadeCaller();
        adapter.exactOutput(p6);
    }

    /// @notice U:[CAMV3-3]: `exactInputSingle` works as expected
    function test_U_CAMV3_03_exactInputSingle_works_as_expected() public {
        ICamelotV3Router.ExactInputSingleParams memory params = ICamelotV3Router.ExactInputSingleParams({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            amountIn: 123,
            amountOutMinimum: 456,
            deadline: 789,
            recipient: creditAccount,
            limitSqrtPrice: 0
        });

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(ICamelotV3Router.exactInputSingle, (params)),
            requiresApproval: true,
            validatesTokens: true
        });

        params.recipient = address(0);
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactInputSingle(params);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CAMV3-3A]: `exactInputSingleSupportingFeeOnTransferTokens` works as expected
    function test_U_CAMV3_03A_exactInputSingleSupportingFeeOnTransferTokens_works_as_expected() public {
        ICamelotV3Router.ExactInputSingleParams memory params = ICamelotV3Router.ExactInputSingleParams({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            amountIn: 123,
            amountOutMinimum: 456,
            deadline: 789,
            recipient: creditAccount,
            limitSqrtPrice: 0
        });

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(ICamelotV3Router.exactInputSingleSupportingFeeOnTransferTokens, (params)),
            requiresApproval: true,
            validatesTokens: true
        });

        params.recipient = address(0);
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) =
            adapter.exactInputSingleSupportingFeeOnTransferTokens(params);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CAMV3-4]: `exactDiffInputSingle` works as expected
    function test_U_CAMV3_04_exactDiffInputSingle_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(
                ICamelotV3Router.exactInputSingle,
                (
                    ICamelotV3Router.ExactInputSingleParams({
                        tokenIn: tokens[0],
                        tokenOut: tokens[1],
                        amountIn: diffInputAmount,
                        amountOutMinimum: diffInputAmount / 2,
                        deadline: 789,
                        recipient: creditAccount,
                        limitSqrtPrice: 0
                    })
                )
                ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactDiffInputSingle(
            ExactDiffInputSingleParams({
                tokenIn: tokens[0],
                tokenOut: tokens[1],
                deadline: 789,
                leftoverAmount: diffLeftoverAmount,
                rateMinRAY: 0.5e27,
                limitSqrtPrice: 0
            })
        );

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 1 : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CAMV3-4A]: `exactDiffInputSingleSupportingFeeOnTransferTokens` works as expected
    function test_U_CAMV3_04A_exactDiffInputSingleSupportingFeeOnTransferTokens_works_as_expected()
        public
        diffTestCases
    {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(
                ICamelotV3Router.exactInputSingleSupportingFeeOnTransferTokens,
                (
                    ICamelotV3Router.ExactInputSingleParams({
                        tokenIn: tokens[0],
                        tokenOut: tokens[1],
                        amountIn: diffInputAmount,
                        amountOutMinimum: diffInputAmount / 2,
                        deadline: 789,
                        recipient: creditAccount,
                        limitSqrtPrice: 0
                    })
                )
                ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactDiffInputSingleSupportingFeeOnTransferTokens(
            ExactDiffInputSingleParams({
                tokenIn: tokens[0],
                tokenOut: tokens[1],
                deadline: 789,
                leftoverAmount: diffLeftoverAmount,
                rateMinRAY: 0.5e27,
                limitSqrtPrice: 0
            })
        );

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 1 : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CAMV3-5]: `exactInput` works as expected
    function test_U_CAMV3_05_exactInput_works_as_expected() public {
        ICamelotV3Router.ExactInputParams memory params = ICamelotV3Router.ExactInputParams({
            path: _makePath(0),
            amountIn: 123,
            amountOutMinimum: 456,
            deadline: 789,
            recipient: creditAccount
        });
        vm.expectRevert(InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.exactInput(params);

        params.path = _makePath(3);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[2],
            callData: abi.encodeCall(ICamelotV3Router.exactInput, (params)),
            requiresApproval: true,
            validatesTokens: true
        });

        params.recipient = address(0);
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactInput(params);

        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CAMV3-6]: `exactDiffInput` works as expected
    function test_U_CAMV3_06_exactDiffInput_works_as_expected() public diffTestCases {
        deal({token: tokens[0], to: creditAccount, give: diffMintedAmount});

        ExactDiffInputParams memory params = ExactDiffInputParams({
            path: _makePath(0),
            deadline: 789,
            leftoverAmount: diffLeftoverAmount,
            rateMinRAY: 0.5e27
        });
        vm.expectRevert(InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.exactDiffInput(params);

        params.path = _makePath(3);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[2],
            callData: abi.encodeCall(
                ICamelotV3Router.exactInput,
                (
                    ICamelotV3Router.ExactInputParams({
                        path: params.path,
                        amountIn: diffInputAmount,
                        amountOutMinimum: diffInputAmount / 2,
                        deadline: 789,
                        recipient: creditAccount
                    })
                )
                ),
            requiresApproval: true,
            validatesTokens: true
        });

        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactDiffInput(params);

        assertEq(tokensToEnable, 4, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, diffDisableTokenIn ? 1 : 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CAMV3-7]: `exactOutputSingle` works as expected
    function test_U_CAMV3_07_exactOutputSingle_works_as_expected() public {
        ICamelotV3Router.ExactOutputSingleParams memory params = ICamelotV3Router.ExactOutputSingleParams({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            fee: 0,
            amountOut: 123,
            amountInMaximum: 456,
            deadline: 789,
            recipient: creditAccount,
            limitSqrtPrice: 0
        });

        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[0],
            tokenOut: tokens[1],
            callData: abi.encodeCall(ICamelotV3Router.exactOutputSingle, (params)),
            requiresApproval: true,
            validatesTokens: true
        });

        params.recipient = address(0);
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactOutputSingle(params);

        assertEq(tokensToEnable, 2, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CAMV3-8]: `exactOutput` works as expected
    function test_U_CAMV3_08_exactOutput_works_as_expected() public {
        ICamelotV3Router.ExactOutputParams memory params = ICamelotV3Router.ExactOutputParams({
            path: _makePath(0),
            amountOut: 123,
            amountInMaximum: 456,
            deadline: 789,
            recipient: creditAccount
        });
        vm.expectRevert(InvalidPathException.selector);
        vm.prank(creditFacade);
        adapter.exactOutput(params);

        params.path = _makePath(3);
        _readsActiveAccount();
        _executesSwap({
            tokenIn: tokens[2], // path is reversed for exactOutput
            tokenOut: tokens[0],
            callData: abi.encodeCall(ICamelotV3Router.exactOutput, (params)),
            requiresApproval: true,
            validatesTokens: true
        });

        params.recipient = address(0);
        vm.prank(creditFacade);
        (uint256 tokensToEnable, uint256 tokensToDisable) = adapter.exactOutput(params);

        assertEq(tokensToEnable, 1, "Incorrect tokensToEnable");
        assertEq(tokensToDisable, 0, "Incorrect tokensToDisable");
    }

    /// @notice U:[CAMV3-9]: `setPoolStatusBatch` works as expected
    function test_U_CAMV3_09_setPoolStatusBatch_works_as_expected() public {
        CamelotV3PoolStatus[] memory pairs;

        _revertsOnNonConfiguratorCaller();
        adapter.setPoolStatusBatch(pairs);

        pairs = new CamelotV3PoolStatus[](2);
        pairs[0] = CamelotV3PoolStatus(tokens[0], tokens[1], false);
        pairs[1] = CamelotV3PoolStatus(tokens[1], tokens[2], true);

        vm.expectEmit(true, true, true, true);
        emit SetPoolStatus(_min(tokens[0], tokens[1]), _max(tokens[0], tokens[1]), false);

        vm.expectEmit(true, true, true, true);
        emit SetPoolStatus(_min(tokens[1], tokens[2]), _max(tokens[1], tokens[2]), true);

        vm.prank(configurator);
        adapter.setPoolStatusBatch(pairs);

        assertFalse(adapter.isPoolAllowed(tokens[0], tokens[1]), "First pool incorrectly allowed");
        assertTrue(adapter.isPoolAllowed(tokens[1], tokens[2]), "Second pool incorrectly not allowed");
    }

    /// @notice U:[CAMV3-10]: `_validatePath` works as expected
    function test_U_CAMV3_10_validatePath_works_as_expected() public {
        bool isValid;
        address tokenIn;
        address tokenOut;
        bytes memory path;

        // insane path
        (isValid,,) = adapter.validatePath(bytes(""));
        assertFalse(isValid, "Empty path incorrectly valid");

        (isValid,,) = adapter.validatePath(bytes("some random string that does not represent a valid path"));
        assertFalse(isValid, "Arbitrary path incorrectly valid");

        // exhaustive search
        for (uint256 pathLen = 2; pathLen <= 4; ++pathLen) {
            path = _makePath(pathLen);

            uint256 numCases = 1 << (pathLen - 1);
            for (uint256 mask; mask < numCases; ++mask) {
                _setPoolsStatus(pathLen - 1, mask);
                (isValid, tokenIn, tokenOut) = adapter.validatePath(path);

                if (mask == numCases - 1) {
                    assertTrue(isValid, "Path incorrectly invalid");
                    assertEq(tokenIn, tokens[0], "Incorrect tokenIn");
                    assertEq(tokenOut, tokens[pathLen - 1], "Incorrect tokenOut");
                } else {
                    assertFalse(isValid, "Path incorrectly valid");
                }
            }
        }
    }

    // ------- //
    // HELPERS //
    // ------- //

    /// @dev Returns swap path of `len` consecutive `tokens`
    function _makePath(uint256 len) internal view returns (bytes memory path) {
        if (len == 2) path = abi.encodePacked(tokens[0], tokens[1]);
        if (len == 3) path = abi.encodePacked(tokens[0], tokens[1], tokens[2]);
        if (len == 4) path = abi.encodePacked(tokens[0], tokens[1], tokens[2], tokens[3]);
    }

    /// @dev Sets statuses for `len` consecutive pools of `tokens` based on `allowedPoolsMask`
    function _setPoolsStatus(uint256 len, uint256 allowedPairsMask) internal {
        CamelotV3PoolStatus[] memory pairs = new CamelotV3PoolStatus[](len);
        for (uint256 i; i < len; ++i) {
            uint256 mask = 1 << i;
            pairs[i] = CamelotV3PoolStatus(tokens[i], tokens[i + 1], allowedPairsMask & mask != 0);
        }
        vm.prank(configurator);
        adapter.setPoolStatusBatch(pairs);
    }

    /// @dev Returns smaller of two addresses
    function _min(address token0, address token1) internal pure returns (address) {
        return token0 < token1 ? token0 : token1;
    }

    /// @dev Returns larger of two addresses
    function _max(address token0, address token1) internal pure returns (address) {
        return token0 < token1 ? token1 : token0;
    }
}
