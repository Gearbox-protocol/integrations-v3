// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2021
pragma solidity ^0.8.10;
pragma abicoder v1;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { AbstractAdapter } from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";

// INTERFACES

import { IAdapter, AdapterType } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import { IwstETH } from "../../integrations/lido/IwstETH.sol";
import { IwstETHV1Adapter } from "../../interfaces/lido/IwstETHV1Adapter.sol";
import { TokenIsNotAddedToCreditManagerException } from "@gearbox-protocol/core-v2/contracts/interfaces/IErrors.sol";

/// @title wstETH adapter
/// @dev Implements logic for wrapping / unwrapping wstETH
contract WstETHV1Adapter is AbstractAdapter, IwstETHV1Adapter, ReentrancyGuard {
    /// @dev Address of the Lido contract
    address public immutable stETH;

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    AdapterType public constant _gearboxAdapterType =
        AdapterType.LIDO_WSTETH_V1;
    uint16 public constant _gearboxAdapterVersion = 1;

    /// @dev Constructor
    /// @param _creditManager Address of the Credit manager
    /// @param _wstETH Address of the wstETH token
    constructor(address _creditManager, address _wstETH)
        AbstractAdapter(_creditManager, _wstETH)
    {
        stETH = IwstETH(_wstETH).stETH(); // F:[AWSTV1-1]

        if (creditManager.tokenMasksMap(_wstETH) == 0)
            revert TokenIsNotAddedToCreditManagerException(_wstETH); // F:[AWSTV1-2]

        if (creditManager.tokenMasksMap(stETH) == 0)
            revert TokenIsNotAddedToCreditManagerException(stETH); // F:[AWSTV1-2]

        name = IwstETH(targetContract).name(); // F:[AWSTV1-1]
        symbol = IwstETH(targetContract).symbol(); // F:[AWSTV1-1]
        decimals = IwstETH(targetContract).decimals(); // F:[AWSTV1-1]
    }

    /**
     * @notice Exchanges stETH to wstETH
     * @param _stETHAmount amount of stETH to wrap in exchange for wstETH
     * @dev Requirements:
     *  - `_stETHAmount` must be non-zero
     *  - msg.sender must approve at least `_stETHAmount` stETH to this
     *    contract.
     *  - msg.sender must have at least `_stETHAmount` of stETH.
     * User should first approve _stETHAmount to the WstETH contract
     * @return Amount of wstETH user receives after wrap
     */
    function wrap(uint256 _stETHAmount) external returns (uint256) {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        ); // F:[AWSTV1-3]

        uint256 amount = IERC20(stETH).balanceOf(creditAccount); // F:[AWSTV1-4,5]
        bool disableTokenIn = amount == _stETHAmount; // F:[AWSTV1-5]
        if (disableTokenIn) --_stETHAmount; // F:[AWSTV1-4]

        return _swap(creditAccount, _stETHAmount, true, disableTokenIn); // F:[AWSTV1-5]
    }

    /**
     * @notice Exchanges all stETH to wstETH
     * User should first approve _stETHAmount to the WstETH contract
     * @return Amount of wstETH user receives after wrap
     */
    function wrapAll() external returns (uint256) {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        ); // F:[AWSTV1-3]

        uint256 amount = IERC20(stETH).balanceOf(creditAccount) - 1; // F:[AWSTV1-4]

        return _swap(creditAccount, amount, true, true); // F:[AWSTV1-4]
    }

    /**
     * @notice Exchanges wstETH to stETH
     * @param _wstETHAmount amount of wstETH to uwrap in exchange for stETH
     * @dev Requirements:
     *  - `_wstETHAmount` must be non-zero
     *  - msg.sender must have at least `_wstETHAmount` wstETH.
     * @return Amount of stETH user receives after unwrap
     */
    function unwrap(uint256 _wstETHAmount) external returns (uint256) {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        ); // F:[AWSTV1-3]

        uint256 amount = IERC20(targetContract).balanceOf(creditAccount); // F: [AWSTV1-6,7]

        bool disableTokenIn = amount == _wstETHAmount; // F: [AWSTV1-6]
        if (disableTokenIn) --_wstETHAmount; // F: [AWSTV1-6]

        return _swap(creditAccount, _wstETHAmount, false, disableTokenIn); // F: [AWSTV1-6,7]
    }

    /**
     * @notice Exchanges all wstETH to stETH
     * @return Amount of stETH user receives after unwrap
     */
    function unwrapAll() external returns (uint256) {
        address creditAccount = creditManager.getCreditAccountOrRevert(
            msg.sender
        ); // F:[AWSTV1-3]

        uint256 amount = IERC20(targetContract).balanceOf(creditAccount) - 1; // F: [AWSTV1-5]

        return _swap(creditAccount, amount, false, true); // F: [AWSTV1-5]
    }

    function _swap(
        address creditAccount,
        uint256 amount,
        bool isWrap,
        bool isAll
    ) internal returns (uint256) {
        return
            abi.decode(
                _safeExecuteFastCheck(
                    creditAccount,
                    isWrap ? stETH : targetContract,
                    isWrap ? targetContract : stETH,
                    abi.encodeWithSelector(
                        isWrap
                            ? IwstETH.wrap.selector
                            : IwstETH.unwrap.selector,
                        amount
                    ),
                    isWrap,
                    isAll
                ),
                (uint256)
            ); // F: [AWSTV1-4,5,6,7]
    }

    /**
     * @notice Get amount of wstETH for a given amount of stETH
     * @param _stETHAmount amount of stETH
     * @return Amount of wstETH for a given stETH amount
     */
    function getWstETHByStETH(uint256 _stETHAmount)
        external
        view
        returns (uint256)
    {
        return IwstETH(targetContract).getWstETHByStETH(_stETHAmount); // F:[AWSTV1-8]
    }

    /**
     * @notice Get amount of stETH for a given amount of wstETH
     * @param _wstETHAmount amount of wstETH
     * @return Amount of stETH for a given wstETH amount
     */
    function getStETHByWstETH(uint256 _wstETHAmount)
        external
        view
        returns (uint256)
    {
        return IwstETH(targetContract).getStETHByWstETH(_wstETHAmount); // F:[AWSTV1-8]
    }

    /**
     * @notice Get amount of stETH for a one wstETH
     * @return Amount of stETH for 1 wstETH
     */
    function stEthPerToken() external view returns (uint256) {
        return IwstETH(targetContract).stEthPerToken(); // F:[AWSTV1-9]
    }

    /**
     * @notice Get amount of wstETH for a one stETH
     * @return Amount of wstETH for a 1 stETH
     */
    function tokensPerStEth() external view returns (uint256) {
        return IwstETH(targetContract).tokensPerStEth(); // F:[AWSTV1-9]
    }

    /// @dev Get ERC20 token balance for an account
    /// @param _account The address to get the balance for
    function balanceOf(address _account) external view returns (uint256) {
        return IwstETH(targetContract).balanceOf(_account); // F:[AWSTV1-11]
    }

    /// @dev Get ERC20 token allowance from owner to spender
    /// @param _owner The address allowing spending
    /// @param _spender The address allowed spending
    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256)
    {
        return IwstETH(targetContract).allowance(_owner, _spender); // F:[AWSTV1-10]
    }

    /// @dev Get ERC20 token total supply
    function totalSupply() external view returns (uint256) {
        return IwstETH(targetContract).totalSupply(); // F:[AWSTV1-11]
    }
}
