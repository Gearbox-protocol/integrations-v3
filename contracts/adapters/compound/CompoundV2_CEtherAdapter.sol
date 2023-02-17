// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AdapterType } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import { CEtherGateway } from "./CEtherGateway.sol";
import { CompoundV2_CTokenAdapter } from "./CompoundV2_CTokenAdapter.sol";
import { ICEther } from "../../integrations/compound/ICEther.sol";

/// @title Compound V2 CEther adapter
contract CompoundV2_CEtherAdapter is CompoundV2_CTokenAdapter {
    /// @notice cToken that this adapter is connected to
    address public immutable override cToken;

    /// @notice cToken's underlying token
    address public immutable override underlying;

    AdapterType public constant _gearboxAdapterType =
        AdapterType.COMPOUND_V2_CETHER;
    uint16 public constant _gearboxAdapterVersion = 1;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _cethGateway CEther gateway contract address
    constructor(
        address _creditManager,
        address _cethGateway
    ) CompoundV2_CTokenAdapter(_creditManager, _cethGateway) {
        cToken = address(CEtherGateway(payable(targetContract)).ceth());
        underlying = address(CEtherGateway(payable(targetContract)).weth());

        if (creditManager.tokenMasksMap(cToken) == 0)
            revert TokenIsNotInAllowedList(cToken);

        if (creditManager.tokenMasksMap(underlying) == 0)
            revert TokenIsNotInAllowedList(underlying);
    }

    /// -------------------------------- ///
    /// VIRTUAL FUNCTIONS IMPLEMENTATION ///
    /// -------------------------------- ///

    /// @dev Internal implementation of `mint`
    ///      - Calls `_executeSwapSafeApprove` because Gateway needs permission to transfer WETH
    ///      - `tokenIn` is WETH
    ///      - `tokenOut` is cETH
    ///      - `disableTokenIn` is set to false because operation doesn't spend the entire balance
    function _mint(uint256 amount) internal override returns (uint256 error) {
        error = abi.decode(
            _executeSwapSafeApprove(
                underlying,
                cToken,
                _encodeMint(amount),
                false
            ),
            (uint256)
        );
    }

    /// @dev Internal implementation of `mintAll`
    ///      - Calls `_executeSwapSafeApprove` because Gateway needs permission to transfer WETH
    ///      - `tokenIn` is WETH
    ///      - `tokenOut` is cETH
    ///      - `disableTokenIn` is set to true because operation spends the entire balance
    function _mintAll() internal override returns (uint256 error) {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );
        uint256 balance = IERC20(underlying).balanceOf(creditAccount);
        if (balance <= 1) return 0;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }

        error = abi.decode(
            _executeSwapSafeApprove(
                creditAccount,
                underlying,
                cToken,
                _encodeMint(amount),
                true
            ),
            (uint256)
        );
    }

    /// @dev Internal implementation of `redeem`
    ///      - Calls `_executeSwapSafeApprove` because Gateway needs permission to transfer cETH
    ///      - `tokenIn` is cETH
    ///      - `tokenOut` is WETH
    ///      - `disableTokenIn` is set to false because operation doesn't spend the entire balance
    function _redeem(uint256 amount) internal override returns (uint256 error) {
        error = abi.decode(
            _executeSwapSafeApprove(
                cToken,
                underlying,
                _encodeRedeem(amount),
                false
            ),
            (uint256)
        );
    }

    /// @dev Internal implementation of `redeemAll`
    ///      - Calls `_executeSwapSafeApprove` because Gateway needs permission to transfer cETH
    ///      - `tokenIn` is cETH
    ///      - `tokenOut` is WETH
    ///      - `disableTokenIn` is set to true because operation spends the entire balance
    function _redeemAll() internal override returns (uint256 error) {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        );
        uint256 balance = ICEther(cToken).balanceOf(creditAccount);
        if (balance <= 1) return 0;

        uint256 amount;
        unchecked {
            amount = balance - 1;
        }

        error = abi.decode(
            _executeSwapSafeApprove(
                creditAccount,
                cToken,
                underlying,
                _encodeRedeem(amount),
                true
            ),
            (uint256)
        );
    }

    /// @dev Internal implementation of `redeemUnderlying`
    ///      - Calls `_executeSwapSafeApprove` because Gateway needs permission to transfer cETH
    ///      - `tokenIn` is cETH
    ///      - `tokenOut` is WETH
    ///      - `disableTokenIn` is set to false because operation doesn't spend the entire balance
    function _redeemUnderlying(
        uint256 amount
    ) internal override returns (uint256 error) {
        error = abi.decode(
            _executeSwapSafeApprove(
                cToken,
                underlying,
                _encodeRedeemUnderlying(amount),
                false
            ),
            (uint256)
        );
    }
}
