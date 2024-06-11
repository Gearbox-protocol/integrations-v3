// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWETH} from "@gearbox-protocol/core-v3/contracts/interfaces/external/IWETH.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

import {ICompoundV2_Exceptions} from "../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";
import {ICEther} from "../../integrations/compound/ICEther.sol";
import {ICErc20Actions} from "../../integrations/compound/ICErc20.sol";

/// @title CEther gateway
/// @notice Wrapper around CEther that uses WETH for all operations instead of ETH
contract CEtherGateway is SanityCheckTrait, ICErc20Actions, ICompoundV2_Exceptions {
    /// @notice WETH token address
    address public immutable weth;

    /// @notice cETH token address
    address public immutable ceth;

    /// @notice Constructor
    /// @param _weth WETH token address
    /// @param _ceth cETH token address
    constructor(address _weth, address _ceth)
        nonZeroAddress(_weth) // U:[CEG-1]
        nonZeroAddress(_ceth) // U:[CEG-1]
    {
        weth = _weth; // U:[CEG-1]
        ceth = _ceth; // U:[CEG-1]
    }

    /// @notice Allows receiving ETH
    receive() external payable {} // U:[CEG-2]

    /// @notice Deposit given amount of WETH into Compound
    ///         WETH must be approved from caller to gateway before the call
    /// @param mintAmount Amount of WETH to deposit
    /// @return error Error code (always zero, added for compatibility)
    function mint(uint256 mintAmount) external override returns (uint256 error) {
        // transfer WETH from caller and unwrap it
        IERC20(weth).transferFrom(msg.sender, address(this), mintAmount);
        IWETH(weth).withdraw(mintAmount); // U:[CEG-3]

        // deposit ETH to Compound
        ICEther(ceth).mint{value: mintAmount}(); // U:[CEG-3]
        error = 0; // U:[CEG-3]

        // send cETH to caller
        IERC20(ceth).transfer(msg.sender, IERC20(ceth).balanceOf(address(this)));
    }

    /// @notice Burn given amount of cETH to withdraw WETH
    ///         cETH must be approved from caller to gateway before the call
    /// @param redeemTokens Amount of cETH to burn
    /// @param error Error code (always zero, added for compatibility)
    function redeem(uint256 redeemTokens) external override returns (uint256 error) {
        // get specified amount of cETH from caller
        IERC20(ceth).transferFrom(msg.sender, address(this), redeemTokens);

        // redeem ETH from Compound
        error = ICEther(ceth).redeem(redeemTokens); // U:[CEG-4]
        if (error != 0) revert CTokenError(error); // U:[CEG-6]

        // wrap ETH and send to caller
        uint256 ethBalance = address(this).balance;
        IWETH(weth).deposit{value: ethBalance}(); // U:[CEG-4]
        IERC20(weth).transfer(msg.sender, ethBalance);
    }

    /// @notice Withdraw given amount of WETH from Compound
    ///         cETH must be approved from caller to gateway before the call
    /// @param redeemAmount Amount of WETH to withdraw
    /// @return error Error code (always zero, added for compatibility)
    function redeemUnderlying(uint256 redeemAmount) external override returns (uint256 error) {
        // transfer all cETH from caller
        IERC20(ceth).transferFrom(msg.sender, address(this), IERC20(ceth).balanceOf(msg.sender));

        // redeem ETH from Compound
        error = ICEther(ceth).redeemUnderlying(redeemAmount); // U:[CEG-5]
        if (error != 0) revert CTokenError(error); // U:[CEG-6]

        // return the remaining cETH (if any) back to caller
        uint256 cethBalance = IERC20(ceth).balanceOf(address(this));
        if (cethBalance > 0) IERC20(ceth).transfer(msg.sender, cethBalance);

        // wrap ETH and send to caller
        uint256 ethBalance = address(this).balance;
        IWETH(weth).deposit{value: ethBalance}(); // U:[CEG-5]
        IERC20(weth).transfer(msg.sender, ethBalance);
    }
}
