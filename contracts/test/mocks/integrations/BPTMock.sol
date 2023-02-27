// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BPTMock is ERC20, Ownable {
    uint8 private immutable _decimals;
    uint256[] weights;
    bytes32 poolId;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256[] memory _weights, bytes32 _poolId)
        ERC20(name_, symbol_)
    {
        _decimals = decimals_;
        weights = _weights;
        poolId = _poolId;
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

    function getNormalizedWeights() external view returns (uint256[] memory) {
        return weights;
    }

    function getPoolId() external view returns (bytes32) {
        return poolId;
    }
}
