// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWETH} from "@gearbox-protocol/core-v2/contracts/interfaces/external/IWETH.sol";
import {ZeroAddressException} from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

import {ICompoundV2_Exceptions} from "../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";
import {ICEther} from "../../integrations/compound/ICEther.sol";
import {ICErc20Actions} from "../../integrations/compound/ICErc20.sol";

/// @title CEther gateway
/// @notice Wrapper around CEther that uses WETH for all operations instead of ETH
contract CEtherGateway is ICErc20Actions, ICompoundV2_Exceptions {
    /// @notice WETH token address
    IWETH public immutable weth;
    /// @notice cETH token address
    ICEther public immutable ceth;

    /// @notice Constructor
    /// @param _weth WETH token address
    /// @param _ceth cETH token address
    constructor(address _weth, address _ceth) {
        if (_weth == address(0) || _ceth == address(0)) {
            revert ZeroAddressException();
        }
        weth = IWETH(_weth);
        ceth = ICEther(_ceth);
    }

    /// @notice Allows receiving ETH
    receive() external payable {}

    /// @notice Deposit given amount of WETH into Compound
    ///         WETH must be approved from caller to gateway before the call
    /// @param mintAmount Amount of WETH to deposit
    /// @return error Error code (always zero, added for compatibility)
    function mint(uint256 mintAmount) external override returns (uint256 error) {
        // transfer WETH from caller and unwrap it
        IERC20(address(weth)).transferFrom(msg.sender, address(this), mintAmount);
        weth.withdraw(mintAmount);

        // deposit ETH to Compound
        ceth.mint{value: mintAmount}();
        error = 0;

        // send cETH to caller
        ceth.transfer(msg.sender, ceth.balanceOf(address(this)));
    }

    /// @notice Burn given amount of cETH to withdraw WETH
    ///         cETH must be approved from caller to gateway before the call
    /// @param redeemTokens Amount of cETH to burn
    /// @param error Error code (always zero, added for compatibility)
    function redeem(uint256 redeemTokens) external override returns (uint256 error) {
        // get specified amount of cETH from caller
        ceth.transferFrom(msg.sender, address(this), redeemTokens);

        // redeem ETH from Compound
        error = ceth.redeem(redeemTokens);
        if (error != 0) revert CTokenError(error);

        // wrap ETH and send to caller
        uint256 ethBalance = address(this).balance;
        weth.deposit{value: ethBalance}();
        weth.transfer(msg.sender, ethBalance);
    }

    /// @notice Withdraw given amount of WETH from Compound
    ///         cETH must be approved from caller to gateway before the call
    /// @param redeemAmount Amount of WETH to withdraw
    /// @return error Error code (always zero, added for compatibility)
    function redeemUnderlying(uint256 redeemAmount) external override returns (uint256 error) {
        // transfer all cETH from caller
        ceth.transferFrom(msg.sender, address(this), ceth.balanceOf(msg.sender));

        // redeem ETH from Compound
        error = ceth.redeemUnderlying(redeemAmount);
        if (error != 0) revert CTokenError(error);

        // return the remaining cETH (if any) back to caller
        uint256 cethBalance = ceth.balanceOf(address(this));
        if (cethBalance > 0) ceth.transfer(msg.sender, cethBalance);

        // wrap ETH and send to caller
        uint256 ethBalance = address(this).balance;
        weth.deposit{value: ethBalance}();
        weth.transfer(msg.sender, ethBalance);
    }
}
