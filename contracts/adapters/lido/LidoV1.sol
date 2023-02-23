// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;
pragma abicoder v1;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AbstractAdapter } from "@gearbox-protocol/core-v2/contracts/adapters/AbstractAdapter.sol";
import { IAdapter, AdapterType } from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import { ACLNonReentrantTrait } from "@gearbox-protocol/core-v2/contracts/core/ACLNonReentrantTrait.sol";
import { IAddressProvider } from "@gearbox-protocol/core-v2/contracts/interfaces/IAddressProvider.sol";
import { ICreditManagerV2 } from "@gearbox-protocol/core-v2/contracts/interfaces/ICreditManagerV2.sol";
import { IPoolService } from "@gearbox-protocol/core-v2/contracts/interfaces/IPoolService.sol";

import { IstETH } from "../../integrations/lido/IstETH.sol";
import { ILidoV1Adapter } from "../../interfaces/lido/ILidoV1Adapter.sol";
import { LidoV1Gateway } from "./LidoV1_WETHGateway.sol";

uint256 constant LIDO_STETH_LIMIT = 20000 ether;

/// @title Lido V1 adapter
/// @dev Implements logic for interacting with the Lido contract through the gateway
contract LidoV1Adapter is
    AbstractAdapter,
    ILidoV1Adapter,
    ACLNonReentrantTrait
{
    /// @dev Address of the Lido contract
    address public immutable override stETH;

    /// @dev Address of WETH
    address public immutable override weth;

    /// @dev Address of Gearbox treasury
    address public immutable override treasury;

    /// @dev The amount of WETH that can be deposited through this adapter
    uint256 public override limit;

    AdapterType public constant _gearboxAdapterType = AdapterType.LIDO_V1;
    uint16 public constant _gearboxAdapterVersion = 2;

    /// @dev Constructor
    /// @param _creditManager Address of the Credit manager
    /// @param _lidoGateway Address of the Lido gateway
    constructor(
        address _creditManager,
        address _lidoGateway
    )
        ACLNonReentrantTrait(
            address(
                IPoolService(ICreditManagerV2(_creditManager).poolService())
                    .addressProvider()
            )
        )
        AbstractAdapter(_creditManager, _lidoGateway)
    {
        IAddressProvider ap = IPoolService(
            ICreditManagerV2(_creditManager).poolService()
        ).addressProvider();

        stETH = address(LidoV1Gateway(payable(_lidoGateway)).stETH()); // F:[LDOV1-1]

        weth = ap.getWethToken(); // F:[LDOV1-1]
        treasury = ap.getTreasuryContract(); // F:[LDOV1-1]
        limit = LIDO_STETH_LIMIT; // F:[LDOV1-1]
    }

    /// @dev Sends an order to stake ETH in Lido and receive stETH (sending WETH through the gateway)
    /// - Checks that the transaction isn't over the limit and decreases the limit by the amount
    /// - Executes a safe allowance fast check call to gateway's `submit`, passing the Gearbox treasury as referral
    /// @param amount The amount of ETH to deposit in Lido
    /// @notice Fast check parameters:
    /// Input token: WETH
    /// Output token: stETH
    /// Input token is allowed, since the gateway does a transferFrom for WETH
    /// The input token does not need to be disabled, because this does not spend the entire
    /// balance, generally
    function submit(uint256 amount) external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[LDOV1-2]
        _submit(amount, creditAccount, false); // F:[LDOV1-3]
    }

    /// @dev Sends an order to stake ETH in Lido and receive stETH (sending all available WETH through the gateway)
    /// - Checks that the transaction isn't over the limit and decreases the limit by the amount
    /// - Executes a safe allowance fast check call to gateway's `submit`, passing the Gearbox treasury as referral
    /// @notice Fast check parameters:
    /// Input token: WETH
    /// Output token: stETH
    /// Input token is allowed, since the gateway does a transferFrom for WETH
    /// The input token does need to be disabled, because this spends the entire balance
    function submitAll() external override creditFacadeOnly {
        address creditAccount = _creditAccount(); // F:[LDOV1-2]

        uint256 amount = IERC20(weth).balanceOf(creditAccount); // F:[LDOV1-4]

        if (amount > 1) {
            unchecked {
                amount--; // F:[LDOV1-4]
            }

            _submit(amount, creditAccount, true); // F:[LDOV1-4]
        }
    }

    function _submit(
        uint256 amount,
        address creditAccount,
        bool disableTokenIn
    ) internal {
        if (amount > limit) revert LimitIsOverException(); // F:[LDOV1-5]

        unchecked {
            limit -= amount; // F:[LDOV1-5]
        }
        _executeSwapSafeApprove(
            creditAccount,
            weth,
            stETH,
            abi.encodeCall(LidoV1Gateway.submit, (amount, treasury)),
            disableTokenIn
        ); // F:[LDOV1-3,4]
    }

    /// @dev Set a new deposit limit
    /// @param _limit New value for the limit
    function setLimit(
        uint256 _limit
    )
        external
        override
        configuratorOnly // F:[LDOV1-6]
    {
        limit = _limit; // F:[LDOV1-7]
        emit NewLimit(_limit); // F:[LDOV1-7]
    }
}
