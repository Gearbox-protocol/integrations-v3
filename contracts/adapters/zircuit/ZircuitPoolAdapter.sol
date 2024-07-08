// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {ZircuitPhantomToken} from "../../helpers/zircuit/ZircuitPhantomToken.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IZircuitPoolAdapter} from "../../interfaces/zircuit/IZircuitPoolAdapter.sol";
import {IPhantomToken} from "../../interfaces/IPhantomToken.sol";
import {IZircuitPool} from "../../integrations/zircuit/IZircuitPool.sol";

contract ZircuitPoolAdapter is AbstractAdapter, IZircuitPoolAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant override contractType = "AD_ZIRCUIT_POOL";
    uint256 public constant override version = 3_10;

    /// @dev Set of all underlyings that have corresponding phantom tokens
    EnumerableSet.AddressSet internal _supportedUnderlyings;

    /// @notice Map from Zircuit underlying to their respective phantom tokens
    mapping(address => address) public tokenToPhantomToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _pool Zircuit pool address
    constructor(address _creditManager, address _pool) AbstractAdapter(_creditManager, _pool) {}

    /// @dev Reverts when attempting to deposit/withdraw an underlying unrecognized by the adapter
    modifier supportedUnderlyingsOnly(address token) {
        if (!_supportedUnderlyings.contains(token)) revert UnsupportedUnderlyingException();
        _;
    }

    // -------- //
    // DEPOSITS //
    // -------- //

    /// @notice Deposit a specified amount of a token into the Zircuit vault
    /// @dev `_for` parameter is ignored, because the receiver is always the credit account
    function depositFor(address _token, address, uint256 _amount)
        external
        creditFacadeOnly // U: [ZIR-1]
        supportedUnderlyingsOnly(_token) // U: [ZIR-1A]
        returns (bool)
    {
        address creditAccount = _creditAccount();
        _deposit(creditAccount, _token, _amount); // U: [ZIR-2]
        return false;
    }

    /// @notice Deposit the entire balance of a token into the Zircuit vault, except the specified amount
    function depositDiff(address _token, uint256 _leftoverAmount)
        external
        creditFacadeOnly // U: [ZIR-1]
        supportedUnderlyingsOnly(_token) // U: [ZIR-1A]
        returns (bool)
    {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(_token).balanceOf(creditAccount);

        if (balance > _leftoverAmount) {
            unchecked {
                _deposit(creditAccount, _token, balance - _leftoverAmount); // U: [ZIR-3]
            }
        }
        return false;
    }

    /// @dev Internal implementation for "depositFor" and "depositDiff"
    function _deposit(address creditAccount, address token, uint256 amount) internal {
        _executeSwapSafeApprove(token, abi.encodeCall(IZircuitPool.depositFor, (token, creditAccount, amount)));
    }

    // ----------- //
    // WITHDRAWALS //
    // ----------- //

    /// @notice Withdraw a specified amount of token from the Zircuit vault
    function withdraw(address _token, uint256 _amount)
        external
        creditFacadeOnly // U: [ZIR-1]
        supportedUnderlyingsOnly(_token) // U: [ZIR-1A]
        returns (bool)
    {
        _execute(msg.data); // U: [ZIR-4]
        return false;
    }

    /// @notice Withdraw the entire balance of a token from the Zircuit vault, except the specified amount
    function withdrawDiff(address _token, uint256 _leftoverAmount)
        external
        creditFacadeOnly // U: [ZIR-1]
        supportedUnderlyingsOnly(_token) // U: [ZIR-1A]
        returns (bool)
    {
        address creditAccount = _creditAccount();
        address phantomToken = tokenToPhantomToken[_token];

        uint256 balance = IERC20(phantomToken).balanceOf(creditAccount);

        if (balance > _leftoverAmount) {
            unchecked {
                _execute(abi.encodeCall(IZircuitPool.withdraw, (_token, balance - _leftoverAmount))); // U: [ZIR-5]
            }
        }

        return false;
    }

    /// @notice Withdraws phantom token for its underlying
    function withdrawPhantomToken(address token, uint256 amount)
        external
        override
        creditFacadeOnly // U: [ZIR-1]
        supportedUnderlyingsOnly(token) // U: [ZIR-1A]
        returns (bool)
    {
        _execute(abi.encodeCall(IZircuitPool.withdraw, (token, amount)));
        return false;
    }

    // ---- //
    // DATA //
    // ---- //

    /// @notice Returns underlyings supported by this adapter (i.e., positions that have corresponding phantom tokens)
    function getSupportedUnderlyings() public view returns (address[] memory) {
        return _supportedUnderlyings.values();
    }

    /// @notice Returns all adapter parameters serialized into a bytes array,
    ///         as well as adapter type and version, to properly deserialize
    function serialize() external view override returns (bytes memory serializedData) {
        address[] memory supportedUnderlyings = getSupportedUnderlyings();
        address[] memory supportedPhantomTokens = new address[](supportedUnderlyings.length);

        uint256 len = supportedUnderlyings.length;

        for (uint256 i = 0; i < len; ++i) {
            supportedPhantomTokens[i] = tokenToPhantomToken[supportedUnderlyings[i]];
        }

        serializedData = abi.encode(creditManager, targetContract, supportedUnderlyings, supportedPhantomTokens);
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Updates the map of underlyings to phantom tokens
    function updateSupportedUnderlyings() external configuratorOnly {
        ICreditManagerV3 cm = ICreditManagerV3(creditManager);

        uint256 len = cm.collateralTokensCount();
        for (uint256 i = 0; i < len; ++i) {
            address token = cm.getTokenByMask(1 << i);
            try IPhantomToken(token).getPhantomTokenInfo() returns (address target, address depositedToken) {
                if (target == targetContract) {
                    _getMaskOrRevert(token);
                    _getMaskOrRevert(depositedToken);

                    tokenToPhantomToken[depositedToken] = token;
                    _supportedUnderlyings.add(depositedToken);
                    emit AddSupportedUnderlying(depositedToken, token);
                }
            } catch {}
        }
    }
}
