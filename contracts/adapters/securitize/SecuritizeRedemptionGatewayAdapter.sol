// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {NotImplementedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {ISecuritizeRedemptionGateway} from "../../interfaces/securitize/ISecuritizeRedemptionGateway.sol";
import {ISecuritizeRedemptionGatewayAdapter} from "../../interfaces/securitize/ISecuritizeRedemptionGatewayAdapter.sol";
import {SecuritizeRedemptionPhantomToken} from "../../helpers/securitize/SecuritizeRedemptionPhantomToken.sol";

/// @title SecuritizeSwap Adapter
/// @notice Implements logic for interacting with the DAI / USDS wrapping contract
contract SecuritizeRedemptionGatewayAdapter is AbstractAdapter, ISecuritizeRedemptionGatewayAdapter {
    bytes32 public constant override contractType = "ADAPTER::SECURITIZE_REDEMPTION";
    uint256 public constant override version = 3_10;

    address public immutable override dsToken;

    address public immutable override stableCoinToken;

    address public immutable override redemptionPhantomToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _targetContract SecuritizeSwap contract
    constructor(address _creditManager, address _targetContract, address _redemptionPhantomToken)
        AbstractAdapter(_creditManager, _targetContract)
    {
        dsToken = ISecuritizeRedemptionGateway(_targetContract).dsToken();
        stableCoinToken = ISecuritizeRedemptionGateway(_targetContract).stableCoinToken();
        redemptionPhantomToken = _redemptionPhantomToken;

        if (SecuritizeRedemptionPhantomToken(redemptionPhantomToken).redemptionGateway() != _targetContract) {
            revert InvalidRedemptionGatewayException();
        }

        _getMaskOrRevert(dsToken);
        _getMaskOrRevert(stableCoinToken);
        _getMaskOrRevert(redemptionPhantomToken);
    }

    function redeem(uint256 dsTokenAmount) external override creditFacadeOnly returns (bool) {
        _redeem(dsTokenAmount);
        return false;
    }

    function redeemDiff(uint256 leftoverAmount) external override creditFacadeOnly returns (bool) {
        address creditAccount = _creditAccount();
        uint256 dsTokenAmount = IERC20(dsToken).balanceOf(creditAccount);
        if (dsTokenAmount <= leftoverAmount) return false;
        unchecked {
            dsTokenAmount -= leftoverAmount;
        }
        _redeem(dsTokenAmount);
        return false;
    }

    function _redeem(uint256 dsTokenAmount) internal {
        _executeSwapSafeApprove(dsToken, abi.encodeCall(ISecuritizeRedemptionGateway.redeem, (dsTokenAmount)));
    }

    function claim(address[] calldata redeemers) external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(ISecuritizeRedemptionGateway.claim, (redeemers)));
        return false;
    }

    function transferRedeemer(address redeemer, address newAccount) external override creditFacadeOnly returns (bool) {
        _execute(abi.encodeCall(ISecuritizeRedemptionGateway.transferRedeemer, (redeemer, newAccount)));
        return true;
    }

    function withdrawPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    function depositPhantomToken(address, uint256) external view override creditFacadeOnly returns (bool) {
        revert NotImplementedException();
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, dsToken, stableCoinToken, redemptionPhantomToken);
    }
}
