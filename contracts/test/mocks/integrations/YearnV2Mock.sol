// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IYVault} from "../../../integrations/yearn/IYVault.sol";

contract YearnV2Mock is IYVault, ERC20, Ownable {
    using SafeERC20 for IERC20;

    address public override token;
    uint256 public override pricePerShare;

    uint256 immutable decimalsMul;

    constructor(address _token)
        ERC20(
            string(abi.encodePacked("yearn ", ERC20(_token).name())),
            string(abi.encodePacked("yv", ERC20(_token).symbol()))
        )
    {
        token = _token;
        decimalsMul = 10 ** ERC20.decimals();
        pricePerShare = decimalsMul;
    }

    function deposit() public override returns (uint256) {
        return deposit(IERC20(token).balanceOf(msg.sender));
    }

    function deposit(uint256 _amount) public override returns (uint256) {
        return deposit(_amount, msg.sender);
    }

    function deposit(uint256 _amount, address recipient) public override returns (uint256 shares) {
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        shares = (_amount * decimalsMul) / pricePerShare;
        _mint(recipient, shares);
    }

    function withdraw() external override returns (uint256) {
        return withdraw(balanceOf(msg.sender));
    }

    function withdraw(uint256 maxShares) public override returns (uint256) {
        return withdraw(maxShares, msg.sender);
    }

    function withdraw(uint256 maxShares, address recipient) public override returns (uint256) {
        return withdraw(maxShares, recipient, 1);
    }

    function withdraw(
        uint256 maxShares,
        address, // recipient,
        uint256 maxLoss
    ) public override returns (uint256 amount) {
        _burn(msg.sender, maxShares);
        amount = (maxShares * pricePerShare) / decimalsMul;

        // pretend that loss is 1 basis point
        require(maxLoss <= 1, "Loss too big");

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function setPricePerShare(uint256 newPrice) public {
        pricePerShare = newPrice;
    }

    function name() public view override(IYVault, ERC20) returns (string memory) {
        return ERC20.name();
    }

    function symbol() public view override(IYVault, ERC20) returns (string memory) {
        return ERC20.symbol();
    }

    function decimals() public view override(IYVault, ERC20) returns (uint8) {
        return ERC20.decimals();
    }

    function mintShares(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
