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

import {IInfinifiUnwindingGateway} from "../../interfaces/infinifi/IInfinifiUnwindingGateway.sol";
import {
    IInfinifiUnwindingGatewayAdapter,
    LockedTokenStatus
} from "../../interfaces/infinifi/IInfinifiUnwindingGatewayAdapter.sol";
import {IInfinifiGateway, IInfinifiLockingController} from "../../integrations/infinifi/IInfinifiGateway.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @title Infinifi Gateway adapter
/// @notice Implements logic for interacting with the Infinifi Gateway
contract InfinifiUnwindingGatewayAdapter is AbstractAdapter, IInfinifiUnwindingGatewayAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::INFINIFI_UNWINDING";
    uint256 public constant override version = 3_10;

    /// @notice The set of allowed locked tokens
    EnumerableSet.AddressSet private _allowedLockedTokens;

    /// @notice The mapping of unwinding epochs to locked tokens
    mapping(uint32 => address) public unwindingEpochToLockedToken;

    /// @notice The mapping of locked tokens to unwinding epochs
    mapping(address => uint32) public lockedTokenToUnwindingEpoch;

    address public immutable infinifiUnwindingPhantomToken;

    constructor(address _creditManager, address _infinifiUnwindingGateway, address _infinifiUnwindingPhantomToken)
        AbstractAdapter(_creditManager, _infinifiUnwindingGateway)
    {
        infinifiUnwindingPhantomToken = _infinifiUnwindingPhantomToken;
    }

    /// @notice Starts unwinding a locked token position
    /// @param shares The amount of shares to unwinding
    /// @param unwindingEpochs The number of epochs to unwinding
    function startUnwinding(uint256 shares, uint32 unwindingEpochs) external override creditFacadeOnly returns (bool) {
        address lockedToken = unwindingEpochToLockedToken[unwindingEpochs];

        if (!_allowedLockedTokens.contains(lockedToken)) {
            revert LockedTokenNotAllowedException();
        }

        _executeSwapSafeApprove(
            lockedToken, abi.encodeCall(IInfinifiUnwindingGateway.startUnwinding, (shares, unwindingEpochs))
        );

        return true;
    }

    /// @notice Withdraws the assets that finished unwinding
    /// @param amount The amount of assets to withdraw
    function withdraw(uint256 amount) external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(IInfinifiUnwindingGateway.withdraw, (amount)));
        return false;
    }

    /// @notice Withdraws phantom token for its underlying
    function withdrawPhantomToken(address token, uint256 amount) external override creditFacadeOnly returns (bool) {
        if (token != infinifiUnwindingPhantomToken) revert IncorrectStakedPhantomTokenException();
        _execute(abi.encodeCall(IInfinifiUnwindingGateway.withdraw, (amount)));
        return false;
    }

    /// @dev It's not possible to deposit from underlying (the vault's asset) into the withdrawal phantom token,
    ///      hence the function is not implemented.
    function depositPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    function getAllowedLockedTokens() public view returns (address[] memory tokens) {
        return _allowedLockedTokens.values();
    }

    function serialize() external view returns (bytes memory) {
        return abi.encode(creditManager, targetContract, getAllowedLockedTokens());
    }

    function setLockedTokenBatchStatus(LockedTokenStatus[] calldata lockedTokens) external configuratorOnly {
        uint256 len = lockedTokens.length;
        address lockingController = IInfinifiUnwindingGateway(targetContract).lockingController();
        for (uint256 i; i < len; ++i) {
            if (
                IInfinifiLockingController(lockingController).shareToken(lockedTokens[i].unwindingEpochs)
                    != lockedTokens[i].lockedToken
            ) {
                revert LockedTokenUnwindingEpochsMismatchException();
            }

            if (lockedTokens[i].allowed) {
                _allowedLockedTokens.add(lockedTokens[i].lockedToken);
                _getMaskOrRevert(lockedTokens[i].lockedToken);
                unwindingEpochToLockedToken[lockedTokens[i].unwindingEpochs] = lockedTokens[i].lockedToken;
                lockedTokenToUnwindingEpoch[lockedTokens[i].lockedToken] = lockedTokens[i].unwindingEpochs;
            } else {
                _allowedLockedTokens.remove(lockedTokens[i].lockedToken);
                delete lockedTokenToUnwindingEpoch[lockedTokens[i].lockedToken];
            }

            emit SetLockedTokenStatus(
                lockedTokens[i].lockedToken, lockedTokens[i].unwindingEpochs, lockedTokens[i].allowed
            );
        }
    }
}
