// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";

import {IERC4626Adapter} from "../../interfaces/erc4626/IERC4626Adapter.sol";

/// @title ERC4626 Vault adapter
/// @notice Implements logic allowing CAs to interact with any standard-compliant ERC4626 vault
contract ERC4626Adapter is AbstractAdapter, IERC4626Adapter {
    /// @notice Address of the underlying asset of the vault
    address public immutable override asset;

    function version() external pure virtual override returns (uint256) {
        return 3_11;
    }

    function contractType() external pure virtual override returns (bytes32) {
        return "ADAPTER::ERC4626_VAULT";
    }

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault ERC4626 vault address
    constructor(address _creditManager, address _vault)
        AbstractAdapter(_creditManager, _vault) // U:[TV-1]
    {
        asset = IERC4626(_vault).asset(); // U:[TV-1]

        // We verify that the vault asset and shares are valid collaterals
        // in the system before deployment
        _getMaskOrRevert(asset); // U:[TV-1]
        _getMaskOrRevert(_vault); // U:[TV-1]
    }

    /// @notice Deposits a specified amount of underlying asset from the credit account
    /// @param assets Amount of asset to deposit
    /// @dev `receiver` is ignored as it is always the credit account
    function deposit(uint256 assets, address)
        external
        override
        creditFacadeOnly // U:[TV-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[TV-3]
        _deposit(creditAccount, assets); // U:[TV-3]
        return false;
    }

    /// @notice Deposits the entire balance of underlying asset from the credit account, except the specified amount
    /// @param leftoverAmount Amount of underlying to keep on the account
    function depositDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[TV-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[TV-4]
        uint256 balance = IERC20(asset).balanceOf(creditAccount); // U:[TV-4]

        if (balance <= leftoverAmount) return false;
        unchecked {
            balance -= leftoverAmount; // U:[TV-4]
        }
        _deposit(creditAccount, balance); // U:[TV-4]
        return false;
    }

    /// @dev Implementation for the deposit function
    function _deposit(address creditAccount, uint256 assets) internal {
        _executeSwapSafeApprove(asset, abi.encodeCall(IERC4626.deposit, (assets, creditAccount))); // U:[TV-3,4]
    }

    /// @notice Deposits an amount of asset required to mint exactly 'shares' of vault shares
    /// @param shares Amount of shares to mint
    /// @dev `receiver` is ignored as it is always the credit account
    function mint(uint256 shares, address)
        external
        override
        creditFacadeOnly // U:[TV-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[TV-5]
        _executeSwapSafeApprove(asset, abi.encodeCall(IERC4626.mint, (shares, creditAccount))); // U:[TV-5]
        return false;
    }

    /// @notice Burns an amount of shares required to get exactly `assets` of asset
    /// @param assets Amount of asset to withdraw
    /// @dev `receiver` and `owner` are ignored, since they are always set to the credit account address
    function withdraw(uint256 assets, address, address)
        external
        virtual
        override
        creditFacadeOnly // U:[TV-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[TV-6]
        _execute(abi.encodeCall(IERC4626.withdraw, (assets, creditAccount, creditAccount))); // U:[TV-6]
        return false;
    }

    /// @notice Burns a specified amount of shares from the credit account
    /// @param shares Amount of shares to burn
    /// @dev `receiver` and `owner` are ignored, since they are always set to the credit account address
    function redeem(uint256 shares, address, address)
        external
        virtual
        override
        creditFacadeOnly // U:[TV-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[TV-7]
        _redeem(creditAccount, shares); // U:[TV-7]
        return false;
    }

    /// @notice Burns the entire balance of shares from the credit account, except the specified amount
    /// @param leftoverAmount Amount of vault token to keep on the account
    function redeemDiff(uint256 leftoverAmount)
        external
        virtual
        override
        creditFacadeOnly // U:[TV-2]
        returns (bool)
    {
        address creditAccount = _creditAccount(); // U:[TV-8]
        uint256 balance = IERC20(targetContract).balanceOf(creditAccount); // U:[TV-8]
        if (balance <= leftoverAmount) return false;
        unchecked {
            balance -= leftoverAmount; // U:[TV-8]
        }
        _redeem(creditAccount, balance); // U:[TV-8]
        return false;
    }

    /// @dev Implementation for the redeem function
    function _redeem(address creditAccount, uint256 shares) internal {
        _execute(abi.encodeCall(IERC4626.redeem, (shares, creditAccount, creditAccount))); // U:[TV-7,8]
    }

    /// @notice Serialized adapter parameters
    function serialize() external view returns (bytes memory serializedData) {
        serializedData = abi.encode(creditManager, targetContract, asset);
    }
}
