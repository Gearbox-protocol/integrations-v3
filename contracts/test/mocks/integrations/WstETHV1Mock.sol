// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {WAD} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IwstETH} from "../../../integrations/lido/IwstETH.sol";

contract WstETHV1Mock is IwstETH, ERC20, Ownable {
    using SafeERC20 for IERC20;

    address public immutable stETH;
    uint256 immutable decimalsMul;
    uint256 public override stEthPerToken;

    constructor(address _token) ERC20(string("Wrapped stETH"), string("wstETH")) {
        stETH = _token;
        decimalsMul = 10 ** ERC20.decimals();
        stEthPerToken = decimalsMul;
    }

    function setStEthPerToken(uint256 value) external {
        stEthPerToken = value;
    }

    function tokensPerStEth() external view returns (uint256) {
        return getWstETHByStETH(WAD);
    }

    function wrap(uint256 _stETHAmount) external returns (uint256 wstETHAmount) {
        IERC20(stETH).safeTransferFrom(msg.sender, address(this), _stETHAmount);
        wstETHAmount = getWstETHByStETH(_stETHAmount);
        _mint(msg.sender, wstETHAmount);
    }

    function unwrap(uint256 _wstETHAmount) external returns (uint256 stETHAmount) {
        stETHAmount = getStETHByWstETH(_wstETHAmount);
        _burn(msg.sender, _wstETHAmount);
        IERC20(stETH).safeTransfer(msg.sender, stETHAmount);
    }

    function getStETHByWstETH(uint256 _wstETHAmount) public view returns (uint256) {
        return (_wstETHAmount * stEthPerToken) / decimalsMul;
    }

    function getWstETHByStETH(uint256 _stETHAmount) public view returns (uint256) {
        return (_stETHAmount * decimalsMul) / stEthPerToken;
    }
}
