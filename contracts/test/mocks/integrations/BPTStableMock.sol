// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BPTStableMock is ERC20, Ownable {
    uint8 private immutable _decimals;
    bytes32 poolId;
    uint256 rate;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, bytes32 _poolId) ERC20(name_, symbol_) {
        _decimals = decimals_;
        poolId = _poolId;
        rate = 1e18;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) external returns (bool) {
        _burn(to, amount);
        return true;
    }

    function setRate(uint256 newRate) external {
        rate = newRate;
    }

    function getRate() external view returns (uint256) {
        return rate;
    }

    function getPoolId() external view returns (bytes32) {
        return poolId;
    }
}
