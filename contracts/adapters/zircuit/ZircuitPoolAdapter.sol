// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {PhantomTokenType} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {ZircuitPhantomToken} from "../../helpers/zircuit/ZircuitPhantomToken.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IZircuitPoolAdapter} from "../../interfaces/zircuit/IZircuitPoolAdapter.sol";
import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";
import {IZircuitPool} from "../../integrations/zircuit/IZircuitPool.sol";

contract ZircuitPoolAdapter is AbstractAdapter, IZircuitPoolAdapter {
    using EnumerableSet for EnumerableSet.AddressSet;

    AdapterType public constant override _gearboxAdapterType = AdapterType.ZIRCUIT_POOL;
    uint16 public constant override _gearboxAdapterVersion = 3_1;

    /// @dev Set of all underlyings that have corresponding phantom tokens
    EnumerableSet.AddressSet internal _supportedUnderlyings;

    /// @notice Map from Zircuit underlying to their respective phantom tokens
    mapping(address => address) public tokenToPhantomToken;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _pool Zircuit pool address
    constructor(address _creditManager, address _pool) AbstractAdapter(_creditManager, _pool) {}

    // -------- //
    // DEPOSITS //
    // -------- //

    /// @notice Deposit a specified amount of a token into the Zircuit vault
    /// @dev `_for` parameter is ignored, because the receiver is always the credit account
    function depositFor(address _token, address, uint256 _amount)
        external
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();
        (tokensToEnable, tokensToDisable) = _deposit(creditAccount, _token, _amount, false);
    }

    /// @notice Deposit the entire balance of a token into the Zircuit vault, except the specified amount
    function depositDiff(address _token, uint256 _leftoverAmount)
        external
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();
        uint256 balance = IERC20(_token).balanceOf(creditAccount);

        if (balance > _leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) =
                    _deposit(creditAccount, _token, balance - _leftoverAmount, _leftoverAmount <= 1);
            }
        }
    }

    /// @dev Internal implementation for "depositFor" and "depositDiff"
    function _deposit(address creditAccount, address token, uint256 amount, bool disableToken)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address phantomToken = tokenToPhantomToken[token];

        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
            token, phantomToken, abi.encodeCall(IZircuitPool.depositFor, (token, creditAccount, amount)), disableToken
        );
    }

    // ----------- //
    // WITHDRAWALS //
    // ----------- //

    /// @notice Withdraw a specified amount of token from the Zircuit vault
    function withdraw(address _token, uint256 _amount)
        external
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();
        address phantomToken = tokenToPhantomToken[_token];
        (tokensToEnable, tokensToDisable) = _withdraw(_token, phantomToken, _amount, false);
    }

    /// @notice Withdraw the entire balance of a token from the Zircuit vault, except the specified amount
    function withdrawDiff(address _token, uint256 _leftoverAmount)
        external
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();
        address phantomToken = tokenToPhantomToken[_token];

        uint256 balance = IERC20(phantomToken).balanceOf(creditAccount);

        if (balance > _leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) =
                    _withdraw(_token, phantomToken, balance - _leftoverAmount, _leftoverAmount <= 1);
            }
        }
    }

    /// @dev Internal implementation for "withdraw" and "withdrawDiff"
    function _withdraw(address token, address phantomToken, uint256 amount, bool disableToken)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (tokensToEnable, tokensToDisable,) = _executeSwapNoApprove(
            phantomToken, token, abi.encodeCall(IZircuitPool.withdraw, (token, amount)), disableToken
        );
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
    function serialize() external view returns (AdapterType, uint16, bytes[] memory) {
        address[] memory supportedUnderlyings = getSupportedUnderlyings();
        address[] memory supportedPhantomTokens = new address[](supportedUnderlyings.length);

        uint256 len = supportedUnderlyings.length;

        for (uint256 i = 0; i < supportedUnderlyings.length; ++i) {
            supportedPhantomTokens[i] = tokenToPhantomToken[supportedUnderlyings[i]];
        }

        bytes[] memory serializedData = new bytes[](4);
        serializedData[0] = abi.encode(creditManager);
        serializedData[1] = abi.encode(targetContract);
        serializedData[2] = abi.encode(supportedUnderlyings);
        serializedData[3] = abi.encode(supportedPhantomTokens);

        return (_gearboxAdapterType, _gearboxAdapterVersion, serializedData);
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Updates the map of underlyings to phantom tokens
    function updatePhantomTokensMap() external configuratorOnly {
        ICreditManagerV3 cm = ICreditManagerV3(creditManager);

        uint256 len = cm.collateralTokensCount();

        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                address token = cm.getTokenByMask(1 << i);
                try IPhantomToken(token)._gearboxPhantomTokenType() returns (PhantomTokenType ptType) {
                    if (ptType == PhantomTokenType.ZIRCUIT_PHANTOM_TOKEN) {
                        address depositedToken = ZircuitPhantomToken(token).underlying();
                        tokenToPhantomToken[depositedToken] = token;
                        _supportedUnderlyings.add(depositedToken);
                        emit SetTokenToPhantomToken(depositedToken, token);
                    }
                } catch {}
            }
        }
    }
}
