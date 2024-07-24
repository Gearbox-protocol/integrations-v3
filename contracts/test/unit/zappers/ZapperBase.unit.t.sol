// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";
import {IERC20PermitAllowed} from "../../../integrations/external/IERC20PermitAllowed.sol";
import {PoolV3Mock} from "../../mocks/pool/PoolV3Mock.sol";
import {ZapperBaseHarness} from "./ZapperBase.harness.sol";

/// @title Zapper base unit test
/// @notice U:[ZB]: Unit tests for zapper base
contract ZapperBaseUnitTest is Test {
    event ConvertTokenInToUnderlying(uint256 tokenInAmount, uint256 assets);
    event ConvertUnderlyingToTokenIn(uint256 assets, uint256 tokenInAmount, address receiver);
    event ConvertSharesToTokenOut(uint256 shares, uint256 tokenOutAmount, address receiver);
    event ConvertTokenOutToShares(uint256 tokenOutAmount, uint256 shares, address owner);

    event Deposit(uint256 assets, uint256 shares, address receiver);
    event Redeem(uint256 assets, uint256 shares, address owner, address receiver);
    event Refer(uint256 referralCode);

    ZapperBaseHarness zapper;
    PoolV3Mock pool;
    ERC20Mock underlying;

    address token1;
    address token2;
    address owner;
    address receiver;
    uint256 referralCode;

    function setUp() public {
        token1 = makeAddr("TOKEN1");
        token2 = makeAddr("TOKEN2");
        owner = makeAddr("ONWER");
        receiver = makeAddr("RECEIVER");
        referralCode = 42069;

        underlying = new ERC20Mock("Test Token", "TEST", 18);

        pool = new PoolV3Mock(address(underlying));
        pool.hackPricePerShare(2 ether);

        zapper = new ZapperBaseHarness(address(pool));
    }

    /// @notice U:[ZB-1]: Constructor works as expected
    function test_U_ZB_01_constructor_works_as_expected() public view {
        assertEq(zapper.pool(), address(pool), "Incorrect pool");
        assertEq(zapper.underlying(), address(underlying), "Incorrect underlying");
        assertEq(underlying.allowance(address(zapper), address(pool)), type(uint256).max, "Incorrect allowance");
    }

    struct PreviewDepositTestCase {
        address tokenIn;
        address tokenOut;
        uint256 tokenInExchangeRate;
        uint256 tokenOutExchangeRate;
        uint256 tokenInAmount;
        uint256 expectedAssets;
        uint256 expectedTokenOutAmount;
    }

    /// @notice U:[ZB-2]: `previewDeposit` works as expected
    function test_U_ZB_02_previewDeposit_works_as_expected() public {
        PreviewDepositTestCase[4] memory cases = [
            PreviewDepositTestCase({
                tokenIn: address(underlying),
                tokenOut: address(pool),
                tokenInExchangeRate: 0,
                tokenOutExchangeRate: 0,
                tokenInAmount: 1 ether,
                expectedAssets: 1 ether,
                expectedTokenOutAmount: 2 ether
            }),
            PreviewDepositTestCase({
                tokenIn: token1,
                tokenOut: address(pool),
                tokenInExchangeRate: 2 ether,
                tokenOutExchangeRate: 0,
                tokenInAmount: 1 ether,
                expectedAssets: 2 ether,
                expectedTokenOutAmount: 4 ether
            }),
            PreviewDepositTestCase({
                tokenIn: address(underlying),
                tokenOut: token2,
                tokenInExchangeRate: 0,
                tokenOutExchangeRate: 0.5 ether,
                tokenInAmount: 1 ether,
                expectedAssets: 1 ether,
                expectedTokenOutAmount: 4 ether
            }),
            PreviewDepositTestCase({
                tokenIn: token1,
                tokenOut: token2,
                tokenInExchangeRate: 2 ether,
                tokenOutExchangeRate: 0.5 ether,
                tokenInAmount: 1 ether,
                expectedAssets: 2 ether,
                expectedTokenOutAmount: 8 ether
            })
        ];

        for (uint256 i; i < cases.length; ++i) {
            zapper.hackTokenIn(cases[i].tokenIn);
            zapper.hackTokenOut(cases[i].tokenOut);
            zapper.hackTokenInExchangeRate(cases[i].tokenInExchangeRate);
            zapper.hackTokenOutExchangeRate(cases[i].tokenOutExchangeRate);

            vm.expectCall(address(pool), abi.encodeCall(pool.previewDeposit, (cases[i].expectedAssets)));
            assertEq(
                zapper.previewDeposit(cases[i].tokenInAmount),
                cases[i].expectedTokenOutAmount,
                string.concat("case #", vm.toString(i))
            );
        }
    }

    struct PreviewRedeemTestCase {
        address tokenIn;
        address tokenOut;
        uint256 tokenInExchangeRate;
        uint256 tokenOutExchangeRate;
        uint256 tokenOutAmount;
        uint256 expectedShares;
        uint256 expectedTokenInAmount;
    }

    /// @notice U:[ZB-3]: `previewRedeem` works as expected
    function test_U_ZB_03_previewRedeem_works_as_expected() public {
        PreviewRedeemTestCase[4] memory cases = [
            PreviewRedeemTestCase({
                tokenIn: address(underlying),
                tokenOut: address(pool),
                tokenInExchangeRate: 0,
                tokenOutExchangeRate: 0,
                tokenOutAmount: 1 ether,
                expectedShares: 1 ether,
                expectedTokenInAmount: 0.5 ether
            }),
            PreviewRedeemTestCase({
                tokenIn: token1,
                tokenOut: address(pool),
                tokenInExchangeRate: 2 ether,
                tokenOutExchangeRate: 0,
                tokenOutAmount: 1 ether,
                expectedShares: 1 ether,
                expectedTokenInAmount: 0.25 ether
            }),
            PreviewRedeemTestCase({
                tokenIn: address(underlying),
                tokenOut: token2,
                tokenInExchangeRate: 0,
                tokenOutExchangeRate: 0.5 ether,
                tokenOutAmount: 1 ether,
                expectedShares: 0.5 ether,
                expectedTokenInAmount: 0.25 ether
            }),
            PreviewRedeemTestCase({
                tokenIn: token1,
                tokenOut: token2,
                tokenInExchangeRate: 2 ether,
                tokenOutExchangeRate: 0.5 ether,
                tokenOutAmount: 1 ether,
                expectedShares: 0.5 ether,
                expectedTokenInAmount: 0.125 ether
            })
        ];

        for (uint256 i; i < cases.length; ++i) {
            zapper.hackTokenIn(cases[i].tokenIn);
            zapper.hackTokenOut(cases[i].tokenOut);
            zapper.hackTokenInExchangeRate(cases[i].tokenInExchangeRate);
            zapper.hackTokenOutExchangeRate(cases[i].tokenOutExchangeRate);

            vm.expectCall(address(pool), abi.encodeCall(pool.previewRedeem, (cases[i].expectedShares)));
            assertEq(
                zapper.previewRedeem(cases[i].tokenOutAmount),
                cases[i].expectedTokenInAmount,
                string.concat("case #", vm.toString(i))
            );
        }
    }

    struct DepositTestCase {
        address tokenIn;
        address tokenOut;
        uint256 tokenInExchangeRate;
        uint256 tokenOutExchangeRate;
        uint256 tokenInAmount;
        uint256 expectedAssets;
        uint256 expectedShares;
        uint256 expectedTokenOutAmount;
        address expectedSharesReceiver;
    }

    /// @notice U:[ZB-4]: `deposit` works as expected
    function test_U_ZB_04_deposit_works_as_expected() public {
        DepositTestCase[4] memory cases = [
            DepositTestCase({
                tokenIn: address(underlying),
                tokenOut: address(pool),
                tokenInExchangeRate: 1 ether,
                tokenOutExchangeRate: 0,
                tokenInAmount: 1 ether,
                expectedAssets: 1 ether,
                expectedShares: 2 ether,
                expectedTokenOutAmount: 2 ether,
                expectedSharesReceiver: receiver
            }),
            DepositTestCase({
                tokenIn: token1,
                tokenOut: address(pool),
                tokenInExchangeRate: 2 ether,
                tokenOutExchangeRate: 0,
                tokenInAmount: 1 ether,
                expectedAssets: 2 ether,
                expectedShares: 4 ether,
                expectedTokenOutAmount: 4 ether,
                expectedSharesReceiver: receiver
            }),
            DepositTestCase({
                tokenIn: address(underlying),
                tokenOut: token2,
                tokenInExchangeRate: 1 ether,
                tokenOutExchangeRate: 0.5 ether,
                tokenInAmount: 1 ether,
                expectedAssets: 1 ether,
                expectedShares: 2 ether,
                expectedTokenOutAmount: 4 ether,
                expectedSharesReceiver: address(zapper)
            }),
            DepositTestCase({
                tokenIn: token1,
                tokenOut: token2,
                tokenInExchangeRate: 2 ether,
                tokenOutExchangeRate: 0.5 ether,
                tokenInAmount: 1 ether,
                expectedAssets: 2 ether,
                expectedShares: 4 ether,
                expectedTokenOutAmount: 8 ether,
                expectedSharesReceiver: address(zapper)
            })
        ];

        for (uint256 i; i < cases.length; ++i) {
            zapper.hackTokenIn(cases[i].tokenIn);
            zapper.hackTokenOut(cases[i].tokenOut);
            zapper.hackTokenInExchangeRate(cases[i].tokenInExchangeRate);
            zapper.hackTokenOutExchangeRate(cases[i].tokenOutExchangeRate);

            for (uint256 j; j < 2; ++j) {
                bool withReferral = j == 1;

                if (cases[i].tokenIn != address(underlying)) {
                    vm.expectEmit(false, false, false, true);
                    emit ConvertTokenInToUnderlying(cases[i].tokenInAmount, cases[i].expectedAssets);
                }

                vm.expectEmit(false, false, false, true);
                emit Deposit(cases[i].expectedAssets, cases[i].expectedShares, cases[i].expectedSharesReceiver);

                if (withReferral) {
                    vm.expectEmit(false, false, false, true);
                    emit Refer(referralCode);
                }

                if (cases[i].tokenOut != address(pool)) {
                    vm.expectEmit(false, false, false, true);
                    emit ConvertSharesToTokenOut(cases[i].expectedShares, cases[i].expectedTokenOutAmount, receiver);
                }

                uint256 tokenOutAmount = withReferral
                    ? zapper.depositWithReferral(cases[i].tokenInAmount, receiver, referralCode)
                    : zapper.deposit(cases[i].tokenInAmount, receiver);

                assertEq(
                    tokenOutAmount,
                    cases[i].expectedTokenOutAmount,
                    string.concat("case #", vm.toString(i), withReferral ? " (with referral)" : "")
                );
            }
        }
    }

    struct RedeemTestCase {
        address tokenIn;
        address tokenOut;
        uint256 tokenInExchangeRate;
        uint256 tokenOutExchangeRate;
        uint256 tokenOutAmount;
        uint256 expectedShares;
        uint256 expectedAssets;
        uint256 expectedTokenInAmount;
        address expectedSharesOwner;
        address expectedAssetsReceiver;
    }

    enum PermitType {
        No,
        EIP2612,
        DAILike
    }

    /// @notice U:[ZB-5]: `redeem` works as expected
    function test_U_ZB_05_redeem_works_as_expected() public {
        RedeemTestCase[4] memory cases = [
            RedeemTestCase({
                tokenIn: address(underlying),
                tokenOut: address(pool),
                tokenInExchangeRate: 0,
                tokenOutExchangeRate: 0,
                tokenOutAmount: 1 ether,
                expectedShares: 1 ether,
                expectedAssets: 0.5 ether,
                expectedTokenInAmount: 0.5 ether,
                expectedSharesOwner: owner,
                expectedAssetsReceiver: receiver
            }),
            RedeemTestCase({
                tokenIn: token1,
                tokenOut: address(pool),
                tokenInExchangeRate: 2 ether,
                tokenOutExchangeRate: 0,
                tokenOutAmount: 1 ether,
                expectedShares: 1 ether,
                expectedAssets: 0.5 ether,
                expectedTokenInAmount: 0.25 ether,
                expectedSharesOwner: owner,
                expectedAssetsReceiver: address(zapper)
            }),
            RedeemTestCase({
                tokenIn: address(underlying),
                tokenOut: token2,
                tokenInExchangeRate: 0,
                tokenOutExchangeRate: 0.5 ether,
                tokenOutAmount: 1 ether,
                expectedShares: 0.5 ether,
                expectedAssets: 0.25 ether,
                expectedTokenInAmount: 0.25 ether,
                expectedSharesOwner: address(zapper),
                expectedAssetsReceiver: receiver
            }),
            RedeemTestCase({
                tokenIn: token1,
                tokenOut: token2,
                tokenInExchangeRate: 2 ether,
                tokenOutExchangeRate: 0.5 ether,
                tokenOutAmount: 1 ether,
                expectedShares: 0.5 ether,
                expectedAssets: 0.25 ether,
                expectedTokenInAmount: 0.125 ether,
                expectedSharesOwner: address(zapper),
                expectedAssetsReceiver: address(zapper)
            })
        ];

        for (uint256 i; i < cases.length; ++i) {
            zapper.hackTokenIn(cases[i].tokenIn);
            zapper.hackTokenOut(cases[i].tokenOut);
            zapper.hackTokenInExchangeRate(cases[i].tokenInExchangeRate);
            zapper.hackTokenOutExchangeRate(cases[i].tokenOutExchangeRate);

            for (uint256 j; j < 3; ++j) {
                PermitType permitType = PermitType(j);

                if (cases[i].tokenOut != address(pool)) {
                    vm.expectEmit(false, false, false, true);
                    emit ConvertTokenOutToShares(cases[i].tokenOutAmount, cases[i].expectedShares, owner);
                }

                vm.expectEmit(false, false, false, true);
                emit Redeem(
                    cases[i].expectedAssets,
                    cases[i].expectedShares,
                    cases[i].expectedSharesOwner,
                    cases[i].expectedAssetsReceiver
                );

                if (cases[i].tokenIn != address(underlying)) {
                    vm.expectEmit(false, false, false, true);
                    emit ConvertUnderlyingToTokenIn(cases[i].expectedAssets, cases[i].expectedTokenInAmount, receiver);
                }

                if (permitType == PermitType.EIP2612) {
                    vm.mockCall(
                        cases[i].tokenOut,
                        abi.encodeCall(
                            IERC20Permit.permit,
                            (owner, address(zapper), cases[i].tokenOutAmount, 0, 0, bytes32(0), bytes32(0))
                        ),
                        bytes("")
                    );
                    vm.expectCall(
                        cases[i].tokenOut,
                        abi.encodeCall(
                            IERC20Permit.permit,
                            (owner, address(zapper), cases[i].tokenOutAmount, 0, 0, bytes32(0), bytes32(0))
                        )
                    );
                } else if (permitType == PermitType.DAILike) {
                    vm.mockCall(
                        cases[i].tokenOut,
                        abi.encodeCall(
                            IERC20PermitAllowed.permit, (owner, address(zapper), 0, 0, true, 0, bytes32(0), bytes32(0))
                        ),
                        bytes("")
                    );
                    vm.expectCall(
                        cases[i].tokenOut,
                        abi.encodeCall(
                            IERC20PermitAllowed.permit, (owner, address(zapper), 0, 0, true, 0, bytes32(0), bytes32(0))
                        )
                    );
                }

                vm.prank(owner);
                uint256 tokenInAmount = permitType == PermitType.EIP2612
                    ? zapper.redeemWithPermit(cases[i].tokenOutAmount, receiver, 0, 0, bytes32(0), bytes32(0))
                    : permitType == PermitType.DAILike
                        ? zapper.redeemWithPermitAllowed(cases[i].tokenOutAmount, receiver, 0, 0, 0, bytes32(0), bytes32(0))
                        : zapper.redeem(cases[i].tokenOutAmount, receiver);

                assertEq(
                    tokenInAmount,
                    cases[i].expectedTokenInAmount,
                    string.concat(
                        "case #",
                        vm.toString(i),
                        permitType == PermitType.EIP2612
                            ? " (with permit)"
                            : permitType == PermitType.DAILike ? " (with DAI permit)" : ""
                    )
                );
            }
        }
    }
}
