// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;
pragma abicoder v1;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";
import {IAdapter, AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";

import {IwstETH} from "../../integrations/lido/IwstETH.sol";
import {IwstETHV1Adapter} from "../../interfaces/lido/IwstETHV1Adapter.sol";

/// @title wstETH adapter
/// @dev Implements logic for wrapping / unwrapping wstETH
contract WstETHV1Adapter is AbstractAdapter, IwstETHV1Adapter {
    /// @dev Address of the Lido contract
    address public immutable override stETH;

    AdapterType public constant _gearboxAdapterType = AdapterType.LIDO_WSTETH_V1;
    uint16 public constant _gearboxAdapterVersion = 2;

    /// @dev Constructor
    /// @param _creditManager Address of the Credit manager
    /// @param _wstETH Address of the wstETH token
    constructor(address _creditManager, address _wstETH) AbstractAdapter(_creditManager, _wstETH) {
        stETH = IwstETH(_wstETH).stETH(); // F:[AWSTV1-1]

        if (creditManager.tokenMasksMap(_wstETH) == 0) {
            revert TokenIsNotInAllowedList(_wstETH);
        } // F:[AWSTV1-2]

        if (creditManager.tokenMasksMap(stETH) == 0) {
            revert TokenIsNotInAllowedList(stETH);
        } // F:[AWSTV1-2]
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
     */
    function wrap(uint256 _stETHAmount) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AWSTV1-3]

        uint256 amount = IERC20(stETH).balanceOf(creditAccount); // F:[AWSTV1-4,5]
        bool disableTokenIn = amount == _stETHAmount; // F:[AWSTV1-5]
        if (disableTokenIn) --_stETHAmount; // F:[AWSTV1-4]

        _wrap(creditAccount, _stETHAmount, disableTokenIn); // F:[AWSTV1-5]
    }

    /**
     * @notice Exchanges all stETH to wstETH
     * User should first approve _stETHAmount to the WstETH contract
     */
    function wrapAll() external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AWSTV1-3]

        uint256 amount = IERC20(stETH).balanceOf(creditAccount) - 1; // F:[AWSTV1-4]

        _wrap(creditAccount, amount, true); // F:[AWSTV1-4]
    }

    function _wrap(address creditAccount, uint256 amount, bool disableTokenIn) internal {
        _executeSwapSafeApprove(
            creditAccount, stETH, targetContract, abi.encodeCall(IwstETH.wrap, (amount)), disableTokenIn
        ); // F: [AWSTV1-4,5]
    }

    /**
     * @notice Exchanges wstETH to stETH
     * @param _wstETHAmount amount of wstETH to uwrap in exchange for stETH
     * @dev Requirements:
     *  - `_wstETHAmount` must be non-zero
     *  - msg.sender must have at least `_wstETHAmount` wstETH.
     */
    function unwrap(uint256 _wstETHAmount) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AWSTV1-3]

        uint256 amount = IERC20(targetContract).balanceOf(creditAccount); // F: [AWSTV1-6,7]

        bool disableTokenIn = amount == _wstETHAmount; // F: [AWSTV1-6]
        if (disableTokenIn) --_wstETHAmount; // F: [AWSTV1-6]

        _unwrap(creditAccount, _wstETHAmount, disableTokenIn); // F: [AWSTV1-6,7]
    }

    /**
     * @notice Exchanges all wstETH to stETH
     */
    function unwrapAll() external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[AWSTV1-3]

        uint256 amount = IERC20(targetContract).balanceOf(creditAccount) - 1; // F: [AWSTV1-6]

        _unwrap(creditAccount, amount, true); // F: [AWSTV1-6]
    }

    function _unwrap(address creditAccount, uint256 amount, bool disableTokenIn) internal {
        _executeSwapNoApprove(
            creditAccount, targetContract, stETH, abi.encodeCall(IwstETH.unwrap, (amount)), disableTokenIn
        ); // F: [AWSTV1-6,7]
    }
}
