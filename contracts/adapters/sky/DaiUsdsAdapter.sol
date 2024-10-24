// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";

import {IDaiUsds} from "../../integrations/sky/IDaiUsds.sol";
import {IDaiUsdsAdapter} from "../../interfaces/sky/IDaiUsdsAdapter.sol";

/// @title DaiUsds Adapter
/// @notice Implements logic for interacting with the DAI / USDS wrapping contract
contract DaiUsdsAdapter is AbstractAdapter, IDaiUsdsAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.DAI_USDS_EXCHANGE;
    uint16 public constant override _gearboxAdapterVersion = 3_00;

    /// @notice DAI token
    address public immutable override dai;

    /// @notice USDS token
    address public immutable override usds;

    /// @notice Collateral token mask of DAI in the credit manager
    uint256 public immutable override daiMask;

    /// @notice Collateral token mask of USDS in the credit manager
    uint256 public immutable override usdsMask;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _targetContract DAI / USDS exchange contract
    constructor(address _creditManager, address _targetContract) AbstractAdapter(_creditManager, _targetContract) {
        dai = IDaiUsds(_targetContract).dai();
        usds = IDaiUsds(_targetContract).usds();

        daiMask = _getMaskOrRevert(dai);
        usdsMask = _getMaskOrRevert(usds);
    }

    /// @notice Swaps given amount of DAI to USDS
    /// @param wad Amount of DAI to swap
    /// @dev `usr` (recipient) is ignored as it is always the Credit Account
    function daiToUsds(address, uint256 wad)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();
        (tokensToEnable, tokensToDisable) = _daiToUsds(creditAccount, wad, false);
    }

    /// @notice Swaps the entire balance of DAI to USDS, except the specified amount
    /// @param leftoverAmount Amount of DAI to keep on the account
    function daiToUsdsDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(dai).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) =
                    _daiToUsds(creditAccount, balance - leftoverAmount, leftoverAmount <= 1);
            }
        }
    }

    /// @dev Internal implementation for `daiToUsds` and `daiToUsdsDiff`
    function _daiToUsds(address creditAccount, uint256 amount, bool disableDai)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(dai, type(uint256).max);
        _execute(abi.encodeCall(IDaiUsds.daiToUsds, (creditAccount, amount)));
        _approveToken(dai, 1);
        (tokensToEnable, tokensToDisable) = (usdsMask, disableDai ? daiMask : 0);
    }

    /// @notice Swaps given amount of USDS to DAI
    /// @param wad Amount of USDS to swap
    /// @dev `usr` (recipient) is ignored as it is always the Credit Account
    function usdsToDai(address, uint256 wad)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();
        (tokensToEnable, tokensToDisable) = _usdsToDai(creditAccount, wad, false);
    }

    /// @notice Swaps the entire balance of USDS to DAI, except the specified amount
    /// @param leftoverAmount Amount of USDS to keep on the account
    function usdsToDaiDiff(uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        uint256 balance = IERC20(usds).balanceOf(creditAccount);
        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable) =
                    _usdsToDai(creditAccount, balance - leftoverAmount, leftoverAmount <= 1);
            }
        }
    }

    /// @dev Internal implementation for `usdsToDai` and `usdsToDaiDiff`
    function _usdsToDai(address creditAccount, uint256 amount, bool disableUsds)
        internal
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        _approveToken(usds, type(uint256).max);
        _execute(abi.encodeCall(IDaiUsds.usdsToDai, (creditAccount, amount)));
        _approveToken(usds, 1);
        (tokensToEnable, tokensToDisable) = (daiMask, disableUsds ? usdsMask : 0);
    }
}
