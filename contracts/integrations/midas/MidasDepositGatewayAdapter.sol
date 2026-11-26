// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";
import {RAY, PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {AbstractAdapter} from "../common/AbstractAdapter.sol";

import {IMidasDepositGateway} from "./interfaces/IMidasDepositGateway.sol";
import {IMidasDepositGatewayAdapter} from "./interfaces/IMidasDepositGatewayAdapter.sol";

/// @title Midas Deposit Gateway adapter
/// @notice Implements delayed-deposit logic for the Midas deposit gateway and handles deposit phantom tokens
contract MidasDepositGatewayAdapter is AbstractAdapter, IMidasDepositGatewayAdapter {
    bytes32 public constant override contractType = "ADAPTER::MIDAS_DEPOSIT_GATEWAY";
    uint256 public constant override version = 3_10;

    /// @notice mToken
    address public immutable override mToken;

    /// @notice Gateway address (same as the adapter's target contract)
    address public immutable override gateway;

    /// @notice Payment token used for deposits
    address public immutable override tokenIn;

    /// @notice Deposit phantom token
    address public immutable override phantomToken;

    /// @dev Without a phantom token there is nothing to price pending deposits with, so a credit account would
    ///      lose the value of everything it sends to the gateway — the whole delayed flow is disabled instead
    modifier whenPhantomTokenSet() {
        if (phantomToken == address(0)) revert PhantomTokenNotSetException();
        _;
    }

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _gateway Midas deposit gateway address
    constructor(address _creditManager, address _gateway) AbstractAdapter(_creditManager, _gateway) {
        gateway = _gateway;
        mToken = IMidasDepositGateway(_gateway).mToken();
        tokenIn = IMidasDepositGateway(_gateway).tokenIn();
        phantomToken = IMidasDepositGateway(_gateway).phantomToken();

        _getMaskOrRevert(mToken);
        _getMaskOrRevert(tokenIn);
        if (phantomToken != address(0)) _getMaskOrRevert(phantomToken);
    }

    /// @notice Grants the greenlisted role to the credit account via the gateway
    function receiveGreenlist() external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(IMidasDepositGateway.receiveGreenlist, ()));
        return false;
    }

    /// @notice Requests a deposit of payment token for mToken
    /// @param amountTokenIn Amount of payment token to deposit
    /// @dev Returns `true` to allow safe pricing for the deposit phantom token
    function depositRequest(uint256 amountTokenIn)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        _depositRequest(amountTokenIn, "");
        return true;
    }

    /// @inheritdoc IMidasDepositGatewayAdapter
    function depositRequest(uint256 amountTokenIn, bytes calldata extraData)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        _depositRequest(amountTokenIn, extraData);
        return true;
    }

    /// @inheritdoc IMidasDepositGatewayAdapter
    function depositRequestDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                _depositRequest(balance - leftoverAmount, "");
            }
            return true;
        }
        return false;
    }

    /// @inheritdoc IMidasDepositGatewayAdapter
    function depositRequestDiff(uint256 leftoverAmount, bytes calldata extraData)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                _depositRequest(balance - leftoverAmount, extraData);
            }
            return true;
        }
        return false;
    }

    function _depositRequest(uint256 amountTokenIn, bytes memory extraData) internal {
        _executeSwapSafeApprove(
            tokenIn, abi.encodeCall(IMidasDepositGateway.requestDeposit, (amountTokenIn, extraData))
        );
    }

    function depositRequestHybrid(uint256 amountTokenIn, uint256 instantShare, uint256 minReceiveAmountInstantShare)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        _depositRequestHybrid(amountTokenIn, instantShare, minReceiveAmountInstantShare, "");
        return true;
    }

    function depositRequestHybrid(
        uint256 amountTokenIn,
        uint256 instantShare,
        uint256 minReceiveAmountInstantShare,
        bytes calldata extraData
    ) external override creditFacadeOnly whenPhantomTokenSet returns (bool) {
        _depositRequestHybrid(amountTokenIn, instantShare, minReceiveAmountInstantShare, extraData);
        return true;
    }

    function depositRequestHybridDiff(uint256 leftoverAmount, uint256 instantShare, uint256 minInstantRateRAY)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                _depositRequestHybrid(
                    balance - leftoverAmount,
                    instantShare,
                    _getMinInstantAmount(balance - leftoverAmount, instantShare, minInstantRateRAY),
                    ""
                );
            }
            return true;
        }
        return false;
    }

    function depositRequestHybridDiff(
        uint256 leftoverAmount,
        uint256 instantShare,
        uint256 minInstantRateRAY,
        bytes calldata extraData
    ) external override creditFacadeOnly whenPhantomTokenSet returns (bool) {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                _depositRequestHybrid(
                    balance - leftoverAmount,
                    instantShare,
                    _getMinInstantAmount(balance - leftoverAmount, instantShare, minInstantRateRAY),
                    extraData
                );
            }
            return true;
        }
        return false;
    }

    function _depositRequestHybrid(
        uint256 amountTokenIn,
        uint256 instantShare,
        uint256 minReceiveAmountInstantShare,
        bytes memory extraData
    ) internal {
        _executeSwapSafeApprove(
            tokenIn,
            abi.encodeCall(
                IMidasDepositGateway.requestDepositHybrid,
                (amountTokenIn, instantShare, minReceiveAmountInstantShare, extraData)
            )
        );
    }

    /// @notice Withdraws minted mToken from the gateway
    /// @param amount Amount to withdraw
    function withdraw(uint256 amount) external override creditFacadeOnly whenPhantomTokenSet returns (bool) {
        _withdraw(amount);
        return false;
    }

    function _withdraw(uint256 amount) internal {
        _execute(abi.encodeCall(IMidasDepositGateway.withdraw, (amount)));
    }

    /// @notice Withdraws mToken from a specific depositor
    /// @param depositor The depositor to withdraw from
    /// @param amount The amount to withdraw
    function withdrawFromDepositor(address depositor, uint256 amount)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        _execute(abi.encodeCall(IMidasDepositGateway.withdrawFromDepositor, (depositor, amount)));
        return false;
    }

    /// @notice Transfers a depositor to a new account
    /// @param depositor The depositor to transfer
    /// @param newAccount The new account to transfer the depositor to
    function transferDepositor(address depositor, address newAccount)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        _execute(abi.encodeCall(IMidasDepositGateway.transferDepositor, (depositor, newAccount)));
        return true;
    }

    /// @notice Withdraws phantom token balance for its tracked output token
    /// @param token Phantom token address
    /// @param amount Amount to withdraw
    function withdrawPhantomToken(address token, uint256 amount)
        external
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        if (token != phantomToken) revert IncorrectStakedPhantomTokenException();

        _withdraw(amount);
        return false;
    }

    /// @notice Deposits phantom token — always reverts, a deposit cannot be un-requested
    function depositPhantomToken(address, uint256)
        external
        view
        override
        creditFacadeOnly
        whenPhantomTokenSet
        returns (bool)
    {
        revert NotImplementedException();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, gateway, mToken, tokenIn, phantomToken);
    }

    function _getMinInstantAmount(uint256 amountTokenIn, uint256 instantShare, uint256 minInstantRateRAY)
        internal
        pure
        returns (uint256)
    {
        return (amountTokenIn * instantShare * minInstantRateRAY) / (PERCENTAGE_FACTOR * RAY);
    }
}
