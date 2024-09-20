// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IERC4626Adapter} from "../../interfaces/erc4626/IERC4626Adapter.sol";

/// @title ERC4626 Vault adapter
/// @notice Implements logic allowing CAs to interact with any standard-compliant ERC4626 vault
contract ERC4626Adapter is AbstractAdapter, IERC4626Adapter {
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice Address of the underlying asset of the vault
    address public immutable override asset;

    /// @notice Mask of the underlying asset of the vault
    uint256 public immutable override assetMask;

    /// @notice Mask of the ERC4626 vault shares
    uint256 public immutable override sharesMask;

    function _gearboxAdapterType() external pure virtual override returns (AdapterType) {
        return AdapterType.ERC4626_VAULT;
    }

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _vault ERC4626 vault address
    constructor(address _creditManager, address _vault)
        AbstractAdapter(_creditManager, _vault) // U:[TV-1]
    {
        asset = IERC4626(_vault).asset(); // U:[TV-1]
        assetMask = _getMaskOrRevert(asset); // U:[TV-1]
        sharesMask = _getMaskOrRevert(_vault); // U:[TV-1]
    }

    /// @notice Deposits a specified amount of underlying asset from the credit account
    /// @param assets Amount of asset to deposit
    /// @dev `receiver` is ignored as it is always the credit account
    function deposit(uint256 assets, address)
        external
        override
        creditFacadeOnly // U:[TV-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[TV-3]
        (tokensToEnable, tokensToDisable) = _deposit(creditAccount, assets, false); // U:[TV-3]
    }

    /// @notice Deposits the entire balance of underlying asset from the credit account, except the specified amount
    /// @param leftoverAmount Amount of underlying to keep on the account
    function depositDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly // U:[TV-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[TV-4]
        uint256 balance = IERC20(asset).balanceOf(creditAccount); // U:[TV-4]

        if (balance <= leftoverAmount) return (0, 0);
        unchecked {
            balance -= leftoverAmount; // U:[TV-4]
        }
        (tokensToEnable, tokensToDisable) = _deposit(creditAccount, balance, leftoverAmount <= 1); // U:[TV-4]
    }

    /// @dev Implementation for the deposit function
    function _deposit(address creditAccount, uint256 assets, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) =
            _executeDeposit(disableTokenIn, abi.encodeCall(IERC4626.deposit, (assets, creditAccount))); // U:[TV-3,4]
    }

    /// @notice Deposits an amount of asset required to mint exactly 'shares' of vault shares
    /// @param shares Amount of shares to mint
    /// @dev `receiver` is ignored as it is always the credit account
    function mint(uint256 shares, address)
        external
        override
        creditFacadeOnly // U:[TV-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[TV-5]
        (tokensToEnable, tokensToDisable) =
            _executeDeposit(false, abi.encodeCall(IERC4626.mint, (shares, creditAccount))); // U:[TV-5]
    }

    /// @notice Burns an amount of shares required to get exactly `assets` of asset
    /// @param assets Amount of asset to withdraw
    /// @dev `receiver` and `owner` are ignored, since they are always set to the credit account address
    function withdraw(uint256 assets, address, address)
        external
        virtual
        override
        creditFacadeOnly // U:[TV-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[TV-6]
        (tokensToEnable, tokensToDisable) =
            _executeWithdrawal(false, abi.encodeCall(IERC4626.withdraw, (assets, creditAccount, creditAccount))); // U:[TV-6]
    }

    /// @notice Burns a specified amount of shares from the credit account
    /// @param shares Amount of shares to burn
    /// @dev `receiver` and `owner` are ignored, since they are always set to the credit account address
    function redeem(uint256 shares, address, address)
        external
        virtual
        override
        creditFacadeOnly // U:[TV-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[TV-7]
        (tokensToEnable, tokensToDisable) = _redeem(creditAccount, shares, false); // U:[TV-7]
    }

    /// @notice Burns the entire balance of shares from the credit account, except the specified amount
    /// @param leftoverAmount Amount of vault token to keep on the account
    function redeemDiff(uint256 leftoverAmount)
        external
        virtual
        override
        creditFacadeOnly // U:[TV-2]
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount(); // U:[TV-8]
        uint256 balance = IERC20(targetContract).balanceOf(creditAccount); // U:[TV-8]
        if (balance <= leftoverAmount) return (0, 0);
        unchecked {
            balance -= leftoverAmount; // U:[TV-8]
        }
        (tokensToEnable, tokensToDisable) = _redeem(creditAccount, balance, leftoverAmount <= 1); // U:[TV-8]
    }

    /// @dev Implementation for the redeem function
    function _redeem(address creditAccount, uint256 shares, bool disableTokenIn)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable) =
            _executeWithdrawal(disableTokenIn, abi.encodeCall(IERC4626.redeem, (shares, creditAccount, creditAccount))); // U:[TV-7,8]
    }

    /// @dev Implementation for deposit (asset => shares) actions execution
    /// @dev All deposit-type actions follow the same structure, with only
    ///      calldata and disabling the input token being different
    function _executeDeposit(bool disableAsset, bytes memory callData)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(asset, type(uint256).max); // U:[TV-3,4,5]
        _execute(callData); // U:[TV-3,4,5]
        _approveToken(asset, 1); // U:[TV-3,4,5]
        tokensToEnable = sharesMask;
        tokensToDisable = disableAsset ? assetMask : 0;
    }

    /// @dev Implementation for withdrawal (shares => asset) actions execution
    /// @dev All withdrawal-type actions follow the same structure, with only
    ///      calldata and disabling the input token being different
    function _executeWithdrawal(bool disableShares, bytes memory callData)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _execute(callData); // U:[TV-6,7,8]
        tokensToEnable = assetMask;
        tokensToDisable = disableShares ? sharesMask : 0;
    }
}
