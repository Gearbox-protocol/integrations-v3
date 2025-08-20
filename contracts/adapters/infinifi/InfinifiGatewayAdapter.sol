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

import {IInfinifiGateway, IInfinifiLockingController} from "../../integrations/infinifi/IInfinifiGateway.sol";
import {IInfinifiGatewayAdapter, LockedTokenStatus} from "../../interfaces/infinifi/IInfinifiGatewayAdapter.sol";

/// @title Infinifi Gateway adapter
/// @notice Implements logic for interacting with the Infinifi Gateway
contract InfinifiGatewayAdapter is AbstractAdapter, IInfinifiGatewayAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "ADAPTER::INFINIFI_GATEWAY";
    uint256 public constant override version = 3_10;

    /// @notice The USDC address
    address public immutable usdc;

    /// @notice The iUSD address
    address public immutable iusd;

    /// @notice The siUSD address
    address public immutable siusd;

    /// @notice The set of allowed locked tokens
    EnumerableSet.AddressSet private _allowedLockedTokens;

    /// @notice The mapping of unwinding epochs to locked tokens
    mapping(uint32 => address) public unwindingEpochToLockedToken;

    /// @notice The mapping of locked tokens to unwinding epochs
    mapping(address => uint32) public lockedTokenToUnwindingEpoch;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _infinifiGateway Infinifi Gateway address
    constructor(address _creditManager, address _infinifiGateway) AbstractAdapter(_creditManager, _infinifiGateway) {
        usdc = IInfinifiGateway(_infinifiGateway).getAddress("USDC");
        iusd = IInfinifiGateway(_infinifiGateway).getAddress("receiptToken");
        siusd = IInfinifiGateway(_infinifiGateway).getAddress("stakedToken");

        _getMaskOrRevert(usdc);
        _getMaskOrRevert(iusd);
        _getMaskOrRevert(siusd);
    }

    /// MINT

    /// @notice Mints iUSD from the underlying asset
    /// @param amount The amount of underlying asset to mint
    /// @dev `to` is ignored, since the recipient is always the credit account
    function mint(address, uint256 amount) external creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        _mint(creditAccount, amount);
        return false;
    }

    /// @notice Mints iUSD from the underlying asset using the entire balance, except for the specified amount
    /// @param leftoverAmount The amount of underlying asset to leave in the credit account
    /// @dev `to` is ignored, since the recipient is always the credit account
    function mintDiff(uint256 leftoverAmount) external creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(usdc).balanceOf(creditAccount);
        if (balance <= leftoverAmount) return false;
        _mint(creditAccount, balance - leftoverAmount);
        return false;
    }

    /// @dev Internal implementation for `mint` and `mintDiff`
    function _mint(address creditAccount, uint256 amount) internal {
        _executeSwapSafeApprove(usdc, abi.encodeCall(IInfinifiGateway.mint, (creditAccount, amount)));
    }

    /// STAKE

    /// @notice Stakes iUSD into siUSD
    /// @param amount The amount of iUSD to stake
    /// @dev `to` is ignored, since the recipient is always the credit account
    function stake(address, uint256 amount) external creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        _stake(creditAccount, amount);
        return false;
    }

    /// @notice Stakes iUSD into siUSD using the entire balance, except for the specified amount
    /// @param leftoverAmount The amount of iUSD to leave in the credit account
    function stakeDiff(uint256 leftoverAmount) external creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(iusd).balanceOf(creditAccount);
        if (balance <= leftoverAmount) return false;
        _stake(creditAccount, balance - leftoverAmount);
        return false;
    }

    /// @dev Internal implementation for `stake` and `stakeDiff`
    function _stake(address creditAccount, uint256 amount) internal {
        _executeSwapSafeApprove(iusd, abi.encodeCall(IInfinifiGateway.stake, (creditAccount, amount)));
    }

    /// UNSTAKE

    /// @notice Unstakes siUSD into iUSD
    /// @param amount The amount of siUSD to unstake
    /// @dev `to` is ignored, since the recipient is always the credit account
    function unstake(address, uint256 amount) external creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        _unstake(creditAccount, amount);
        return false;
    }

    /// @notice Unstakes siUSD into iUSD using the entire balance, except for the specified amount
    /// @param leftoverAmount The amount of siUSD to leave in the credit account
    function unstakeDiff(uint256 leftoverAmount) external creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(siusd).balanceOf(creditAccount);
        if (balance <= leftoverAmount) return false;
        _unstake(creditAccount, balance - leftoverAmount);
        return false;
    }

    /// @dev Internal implementation for `unstake` and `unstakeDiff`
    function _unstake(address creditAccount, uint256 amount) internal {
        _executeSwapSafeApprove(siusd, abi.encodeCall(IInfinifiGateway.unstake, (creditAccount, amount)));
    }

    /// CREATE POSITION

    /// @notice Creates a locked token position from iUSD
    /// @param amount The amount of iUSD to lock
    /// @param unwindingEpochs The unwinding duration of the locked position
    /// @dev `to` is ignored, since the recipient is always the credit account
    function createPosition(uint256 amount, uint32 unwindingEpochs) external creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        _createPosition(creditAccount, amount, unwindingEpochs);
        return false;
    }

    /// @notice Creates a locked token position from iUSD using the entire balance, except for the specified amount
    /// @param leftoverAmount The amount of iUSD to leave in the credit account
    /// @param unwindingEpochs The unwinding duration of the locked position
    function createPositionDiff(uint256 leftoverAmount, uint32 unwindingEpochs)
        external
        creditFacadeOnly
        returns (bool)
    {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(iusd).balanceOf(creditAccount);
        if (balance <= leftoverAmount) return false;
        _createPosition(creditAccount, balance - leftoverAmount, unwindingEpochs);
        return false;
    }

    /// @dev Internal implementation for `createPosition` and `createPositionDiff`
    function _createPosition(address creditAccount, uint256 amount, uint32 unwindingEpochs) internal {
        if (!_allowedLockedTokens.contains(unwindingEpochToLockedToken[unwindingEpochs])) {
            revert LockedTokenNotAllowedException();
        }

        _executeSwapSafeApprove(
            iusd, abi.encodeCall(IInfinifiGateway.createPosition, (amount, unwindingEpochs, creditAccount))
        );
    }

    /// REDEEM

    /// @notice Redeems iUSD for the underlying asset
    /// @param amount The amount of iUSD to redeem
    /// @param minAssetsOut The minimum amount of underlying asset to receive
    /// @dev `to` is ignored, since the recipient is always the credit account
    function redeem(address, uint256 amount, uint256 minAssetsOut) external creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        _redeem(creditAccount, amount, minAssetsOut);
        return false;
    }

    /// @notice Redeems iUSD for the underlying asset using the entire balance, except for the specified amount
    /// @param leftoverAmount The amount of iUSD to leave in the credit account
    /// @param minRateRAY The minimum rate of underlying asset to receive
    function redeemDiff(uint256 leftoverAmount, uint256 minRateRAY) external creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(iusd).balanceOf(creditAccount);
        if (balance <= leftoverAmount) return false;
        uint256 amount = balance - leftoverAmount;
        _redeem(creditAccount, amount, amount * minRateRAY / RAY);
        return false;
    }

    /// @dev Internal implementation for `redeem` and `redeemDiff`
    function _redeem(address creditAccount, uint256 amount, uint256 minAssetsOut) internal {
        _executeSwapSafeApprove(iusd, abi.encodeCall(IInfinifiGateway.redeem, (creditAccount, amount, minAssetsOut)));
    }

    /// @notice Claims iUSD redemptions that are enqueued
    /// @dev Although this adapter only supports immediate redemptions and enqueued redemptions are not considered collateral,
    ///      the function is left in to allow claiming delayed redemptions created accidentally
    function claimRedemption() external creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(IInfinifiGateway.claimRedemption, ()));
        return false;
    }

    /// DATA

    /// @notice Returns the set of allowed locked tokens
    function getAllowedLockedTokens() public view returns (address[] memory tokens) {
        return _allowedLockedTokens.values();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory) {
        return abi.encode(creditManager, targetContract, usdc, iusd, siusd, getAllowedLockedTokens());
    }

    /// CONFIGURATION

    function setLockedTokenBatchStatus(LockedTokenStatus[] calldata lockedTokens) external configuratorOnly {
        uint256 len = lockedTokens.length;
        address lockingController = IInfinifiGateway(targetContract).getAddress("lockingController");
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
