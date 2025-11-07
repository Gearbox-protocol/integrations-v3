// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2025.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RAY} from "@gearbox-protocol/core-v3/contracts/libraries/Constants.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IPoolV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPoolV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {
    IKelpLRTWithdrawalManagerAdapter,
    TokenOutStatus
} from "../../interfaces/kelp/IKelpLRTWithdrawalManagerAdapter.sol";
import {IKelpLRTWithdrawalManagerGateway} from "../../interfaces/kelp/IKelpLRTWithdrawalManagerGateway.sol";
import {KelpLRTWithdrawalPhantomToken} from "../../helpers/kelp/KelpLRTWithdrawalPhantomToken.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Kelp LRT Withdrawal Manager adapter
/// @notice Implements logic for interacting with the Kelp LRT Withdrawal Manager
contract KelpLRTWithdrawalManagerAdapter is AbstractAdapter, IKelpLRTWithdrawalManagerAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::KELP_WITHDRAWAL";
    uint256 public constant override version = 3_10;

    /// @notice The set of allowed tokens out
    EnumerableSet.AddressSet private _allowedTokensOut;

    /// @notice The withdrawal manager gateway
    address public immutable withdrawalManagerGateway;

    /// @notice The referral ID
    string public referralId;

    /// @notice The rsETH token
    address public immutable rsETH;

    /// @notice The mapping of token out to phantom token
    mapping(address => address) public tokenOutToPhantomToken;

    /// @notice The mapping of phantom token to token out
    mapping(address => address) public phantomTokenToTokenOut;

    /// @notice Constructor
    constructor(address _creditManager, address _withdrawalManagerGateway, string memory _referralId)
        AbstractAdapter(_creditManager, _withdrawalManagerGateway)
    {
        withdrawalManagerGateway = _withdrawalManagerGateway;
        referralId = _referralId;
        rsETH = IKelpLRTWithdrawalManagerGateway(withdrawalManagerGateway).rsETH();
        _getMaskOrRevert(rsETH);
    }

    /// @notice Initiates a withdrawal for a specific amount of assets
    /// @param asset The asset to withdraw
    /// @param amount The amount of rsETH to redeem
    function initiateWithdrawal(address asset, uint256 amount, string calldata)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        if (!_allowedTokensOut.contains(asset)) revert TokenNotAllowedException();
        _initiateWithdrawal(asset, amount);
        return true;
    }

    /// @notice Initiates a withdrawal for a specific amount of assets, except the specified amount
    /// @param asset The asset to withdraw
    /// @param leftoverAmount The amount of rsETH to leave on the credit account
    function initiateWithdrawalDiff(address asset, uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        if (!_allowedTokensOut.contains(asset)) revert TokenNotAllowedException();

        address creditAccount = _creditAccount();

        uint256 amount = IERC20(asset).balanceOf(creditAccount);

        if (amount < leftoverAmount) return false;

        unchecked {
            amount -= leftoverAmount;
        }

        _initiateWithdrawal(asset, amount);
        return true;
    }

    /// @notice Claims a specific amount of assets from completed withdrawals
    /// @param asset The asset to withdraw
    /// @param amount The amount of asset to claim
    function completeWithdrawal(address asset, uint256 amount, string calldata)
        external
        override
        creditFacadeOnly
        returns (bool)
    {
        if (!_allowedTokensOut.contains(asset)) revert TokenNotAllowedException();
        _completeWithdrawal(asset, amount);
        return false;
    }

    /// @notice Internal implementation for `initiateWithdrawal`
    function _initiateWithdrawal(address asset, uint256 amount) internal {
        _executeSwapSafeApprove(
            rsETH, abi.encodeCall(IKelpLRTWithdrawalManagerGateway.initiateWithdrawal, (asset, amount, referralId))
        );
    }

    /// @notice Internal implementation for `completeWithdrawal`
    function _completeWithdrawal(address asset, uint256 amount) internal {
        _execute(abi.encodeCall(IKelpLRTWithdrawalManagerGateway.completeWithdrawal, (asset, amount, referralId)));
    }

    /// @notice Withdraws phantom token for its underlying
    function withdrawPhantomToken(address token, uint256 amount) external override creditFacadeOnly returns (bool) {
        address asset = phantomTokenToTokenOut[token];
        if (!_allowedTokensOut.contains(asset)) revert IncorrectStakedPhantomTokenException();
        _completeWithdrawal(asset, amount);
        return false;
    }

    /// @dev It's not possible to deposit from underlying (the vault's asset) into the withdrawal phantom token,
    ///      hence the function is not implemented.
    function depositPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    /// @notice Returns the list of allowed withdrawable tokens
    function getAllowedTokensOut() public view returns (address[] memory tokens) {
        return _allowedTokensOut.values();
    }

    /// @notice Returns the list of phantom tokens associated with allowed withdrawable tokens
    function getPhantomTokensForAllowedTokensOut() public view returns (address[] memory phantomTokens) {
        address[] memory tokens = getAllowedTokensOut();
        phantomTokens = new address[](tokens.length);
        for (uint256 i; i < tokens.length; ++i) {
            phantomTokens[i] = tokenOutToPhantomToken[tokens[i]];
        }
        return phantomTokens;
    }

    /// @notice Returns the serialized adapter parameters
    function serialize() external view returns (bytes memory) {
        return abi.encode(creditManager, targetContract, getAllowedTokensOut(), getPhantomTokensForAllowedTokensOut());
    }

    /// @notice Sets the status of a batch of output tokens
    function setTokensOutBatchStatus(TokenOutStatus[] calldata tokensOut) external configuratorOnly {
        uint256 len = tokensOut.length;
        for (uint256 i; i < len; ++i) {
            if (tokensOut[i].allowed) {
                _getMaskOrRevert(tokensOut[i].tokenOut);
                _getMaskOrRevert(tokensOut[i].phantomToken);
                if (KelpLRTWithdrawalPhantomToken(tokensOut[i].phantomToken).tokenOut() != tokensOut[i].tokenOut) {
                    revert IncorrectStakedPhantomTokenException();
                }
                _allowedTokensOut.add(tokensOut[i].tokenOut);
                tokenOutToPhantomToken[tokensOut[i].tokenOut] = tokensOut[i].phantomToken;
                phantomTokenToTokenOut[tokensOut[i].phantomToken] = tokensOut[i].tokenOut;
            } else {
                _allowedTokensOut.remove(tokensOut[i].tokenOut);
                address phantomToken = tokenOutToPhantomToken[tokensOut[i].tokenOut];
                delete tokenOutToPhantomToken[tokensOut[i].tokenOut];
                delete phantomTokenToTokenOut[phantomToken];
            }
        }
    }
}
