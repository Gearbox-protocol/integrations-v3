// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.17;

import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IZapper} from "../../../interfaces/zappers/IZapper.sol";
import {ETH_ADDRESS, IETHZapperDeposits} from "../../../interfaces/zappers/IETHZapperDeposits.sol";
import {IERC20ZapperDeposits} from "../../../interfaces/zappers/IERC20ZapperDeposits.sol";

import {ZapperLiveTestHelper} from "../../suites/ZapperLiveTestHelper.sol";

/// @notice Generic test for all deployed zappers.
/// @dev    Deposits and redeems might revert for various natural reasons not necessarily related to zapper's correctness,
///         which can't be handled in the general case and must be dealt with in specialized tests. This test simply wraps
///         all reverts to avoid unnecessary false negatives, and only ensures that *non-reverting* zappers work properly.
contract AllZappersLiveTest is ZapperLiveTestHelper {
    using SafeERC20 for ERC20;

    address user = makeAddr("user");
    address receiver = makeAddr("receiver");

    function test_live_all_zappers() public attachOrLiveZapperTest {
        emit log_string("");
        emit log_named_address("Pool", address(pool));
        address[] memory zappers = zapperRegister.zappers(address(pool));
        for (uint256 i; i < zappers.length; ++i) {
            emit log_string("");
            emit log_named_address("Zapper", zappers[i]);

            address tokenIn = IZapper(zappers[i]).tokenIn();
            address tokenOut = IZapper(zappers[i]).tokenOut();
            emit log_named_address("Input token", tokenIn);
            emit log_named_address("Output token", tokenOut);

            uint256 snapshot = vm.snapshot();
            _test_deposit(zappers[i], tokenIn, tokenOut);
            vm.revertTo(snapshot);
            _test_redeem(zappers[i], tokenIn, tokenOut);
            vm.revertTo(snapshot);
        }
    }

    function _test_deposit(address zapper, address tokenIn, address tokenOut) internal {
        uint256 tokenInDecimals = (tokenIn == ETH_ADDRESS ? 18 : ERC20(tokenIn).decimals());
        uint256 tokenOutDecimals = ERC20(tokenOut).decimals();

        uint256 tokenInAmount = 10 ** tokenInDecimals;
        try IZapper(zapper).previewDeposit(tokenInAmount) returns (uint256 previewAmountOut) {
            assertGt(previewAmountOut, 0, "Deposit preview returns 0");
            uint256 tokenOutBalanceBefore = ERC20(tokenOut).balanceOf(receiver);

            (uint256 tokenOutAmount, bool success, bytes memory reason) = tokenIn == ETH_ADDRESS
                ? _depositETH(zapper, tokenInAmount)
                : _depositERC20(zapper, tokenIn, tokenInAmount);
            if (!success) {
                emit log_string(string.concat("Deposit failed, reason: ", vm.toString(reason)));
                return;
            }

            assertGe(tokenOutAmount, previewAmountOut, "previewDeposit overestimates");
            uint256 tokenOutBalanceAfter = ERC20(tokenOut).balanceOf(receiver);
            assertEq(tokenOutBalanceAfter, tokenOutBalanceBefore + tokenOutAmount, "Incorrect amount received");

            emit log_named_decimal_uint("Deposited", tokenInAmount, tokenInDecimals);
            emit log_named_decimal_uint("Received", tokenOutAmount, tokenOutDecimals);
        } catch (bytes memory reason) {
            if (_isNotImplementedException(reason)) {
                emit log_string("Deposit is not supported");
            } else {
                emit log_string(string.concat("Deposit preview failed, reason: ", vm.toString(reason)));
            }
        }
    }

    function _test_redeem(address zapper, address tokenIn, address tokenOut) internal {
        uint256 tokenInDecimals = tokenIn == ETH_ADDRESS ? 18 : ERC20(tokenIn).decimals();
        uint256 tokenOutDecimals = ERC20(tokenOut).decimals();

        uint256 tokenOutAmount = 10 ** tokenOutDecimals;
        try IZapper(zapper).previewRedeem(tokenOutAmount) returns (uint256 previewAmountIn) {
            assertGt(previewAmountIn, 0, "Redeem preview returns 0");
            uint256 tokenInBalanceBefore =
                tokenIn == ETH_ADDRESS ? address(receiver).balance : ERC20(tokenIn).balanceOf(receiver);

            (uint256 tokenInAmount, bool success, bytes memory reason) = _redeem(zapper, tokenOut, tokenOutAmount);
            if (!success) {
                emit log_string(string.concat("Redeem failed, reason: ", vm.toString(reason)));
                return;
            }

            assertGe(tokenInAmount, previewAmountIn, "Redeem preview overestimates");
            uint256 tokenInBalanceAfter =
                tokenIn == ETH_ADDRESS ? address(receiver).balance : ERC20(tokenIn).balanceOf(receiver);
            assertEq(tokenInBalanceAfter, tokenInBalanceBefore + tokenInAmount, "Incorrect amount received");

            emit log_named_decimal_uint("Redeemed", tokenOutAmount, tokenOutDecimals);
            emit log_named_decimal_uint("Received", tokenInAmount, tokenInDecimals);
        } catch (bytes memory reason) {
            if (_isNotImplementedException(reason)) {
                emit log_string("Redeem is not supported");
            } else {
                emit log_string(string.concat("Redeem preview failed, reason: ", vm.toString(reason)));
            }
        }
    }

    function _depositETH(address zapper, uint256 tokenInAmount)
        internal
        returns (uint256 tokenOutAmount, bool success, bytes memory revertReason)
    {
        deal(user, tokenInAmount);
        vm.prank(user);
        try IETHZapperDeposits(zapper).deposit{value: tokenInAmount}(receiver) returns (uint256 value) {
            tokenOutAmount = value;
            success = true;
        } catch (bytes memory reason) {
            revertReason = reason;
        }
    }

    function _depositERC20(address zapper, address tokenIn, uint256 tokenInAmount)
        internal
        returns (uint256 tokenOutAmount, bool success, bytes memory revertReason)
    {
        deal(tokenIn, user, tokenInAmount);
        vm.startPrank(user);
        ERC20(tokenIn).forceApprove(zapper, tokenInAmount);
        try IERC20ZapperDeposits(zapper).deposit(tokenInAmount, receiver) returns (uint256 value) {
            tokenOutAmount = value;
            success = true;
        } catch (bytes memory reason) {
            revertReason = reason;
        }
        vm.stopPrank();
    }

    function _redeem(address zapper, address tokenOut, uint256 tokenOutAmount)
        internal
        returns (uint256 tokenInAmount, bool success, bytes memory revertReason)
    {
        deal(tokenOut, user, tokenOutAmount);
        vm.startPrank(user);
        ERC20(tokenOut).forceApprove(zapper, tokenOutAmount);
        try IZapper(zapper).redeem(tokenOutAmount, receiver) returns (uint256 value) {
            tokenInAmount = value;
            success = true;
        } catch (bytes memory reason) {
            revertReason = reason;
        }
        vm.stopPrank();
    }

    function _isNotImplementedException(bytes memory reason) internal pure returns (bool) {
        // bytes4(keccak256(bytes("NotImplementedException()")))
        return reason.length == 4 && bytes4(reason) == 0x24e46f70;
    }
}
