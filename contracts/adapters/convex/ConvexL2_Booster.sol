// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ICreditConfiguratorV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditConfiguratorV3.sol";

import {AbstractAdapter} from "../AbstractAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";

import {IBooster_L2} from "../../integrations/convex/IBooster_L2.sol";
import {IConvexRewardPool_L2} from "../../integrations/convex/IConvexRewardPool_L2.sol";
import {IConvexL2BoosterAdapter} from "../../interfaces/convex/IConvexL2BoosterAdapter.sol";
import {IConvexL2RewardPoolAdapter} from "../../interfaces/convex/IConvexL2RewardPoolAdapter.sol";

/// @title Convex L2 Booster adapter
/// @notice Implements logic allowing CAs to interact with the L2 implementation of Convex Booster
contract ConvexL2BoosterAdapter is AbstractAdapter, IConvexL2BoosterAdapter {
    AdapterType public constant override _gearboxAdapterType = AdapterType.CONVEX_L2_BOOSTER;
    uint16 public constant override _gearboxAdapterVersion = 3_01;

    /// @notice Constructor
    /// @param _creditManager Credit manager address
    /// @param _booster Booster contract address
    constructor(address _creditManager, address _booster) AbstractAdapter(_creditManager, _booster) {}

    // ------- //
    // DEPOSIT //
    // ------- //

    /// @notice Deposits Curve LP tokens into Booster
    /// @param _pid ID of the pool to deposit to
    /// @dev `_amount` parameter is ignored since calldata is passed directly to the target contract
    function deposit(uint256 _pid, uint256)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        (address tokenIn,, address tokenOut,,) = IBooster_L2(targetContract).poolInfo(_pid);
        (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(tokenIn, tokenOut, msg.data, false);
    }

    /// @notice Deposits the entire balance of Curve LP tokens into Booster, except the specified amount
    /// @param _pid ID of the pool to deposit to
    /// @param leftoverAmount Amount of Curve LP to keep on the account
    function depositDiff(uint256 _pid, uint256 leftoverAmount)
        external
        override
        creditFacadeOnly
        returns (uint256 tokensToEnable, uint256 tokensToDisable)
    {
        address creditAccount = _creditAccount();

        (address tokenIn,, address tokenOut,,) = IBooster_L2(targetContract).poolInfo(_pid);

        uint256 balance = IERC20(tokenIn).balanceOf(creditAccount);

        if (balance > leftoverAmount) {
            unchecked {
                (tokensToEnable, tokensToDisable,) = _executeSwapSafeApprove(
                    tokenIn,
                    tokenOut,
                    abi.encodeCall(IBooster_L2.deposit, (_pid, balance - leftoverAmount)),
                    leftoverAmount <= 1
                );
            }
        }
    }
}
