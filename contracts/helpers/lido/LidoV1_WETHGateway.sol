// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;
pragma abicoder v1;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "@gearbox-protocol/core-v3/contracts/interfaces/external/IWETH.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";
import {ReceiveIsNotAllowedException} from "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

import {IstETH} from "../../integrations/lido/IstETH.sol";

/// @title LidoV1 Gateway
/// @notice Allows to submit WETH directly into stETH contract
contract LidoV1Gateway is SanityCheckTrait {
    /// @notice WETH token
    address public immutable weth;

    /// @notice stETH token
    address public immutable stETH;

    /// @notice Constructor
    /// @param _weth WETH token address
    /// @param _stETH stETH contract address
    constructor(address _weth, address _stETH)
        nonZeroAddress(_weth) // U:[LWG-1]
        nonZeroAddress(_stETH) // U:[LWG-1]
    {
        weth = _weth; // U:[LWG-1]
        stETH = _stETH; // U:[LWG-1]
    }

    /// @notice Allows this contract to unwrap WETH, forbids receiving ETH in other ways
    receive() external payable {
        if (msg.sender != weth) revert ReceiveIsNotAllowedException(); // U:[LWG-2]
    }

    /// @notice Submits WETH to the stETH contract by first unwrapping it
    /// @param amount Amount of WETH to submit
    /// @param _referral The address of the referrer
    function submit(uint256 amount, address _referral) external returns (uint256 value) {
        IERC20(weth).transferFrom(msg.sender, address(this), amount);
        IWETH(weth).withdraw(amount); // U:[LWG-3]

        value = IstETH(stETH).submit{value: amount}(_referral); // U:[LWG-3]
        IERC20(stETH).transfer(msg.sender, IERC20(stETH).balanceOf(address(this)));
    }
}
