// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ACLTrait} from "@gearbox-protocol/core-v3/contracts/traits/ACLTrait.sol";
import {ICreditAccountV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditAccountV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {IDiscountSwapper} from "../../interfaces/discount/IDiscountSwapper.sol";
import {SanityCheckTrait} from "@gearbox-protocol/core-v3/contracts/traits/SanityCheckTrait.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Discount Swapper
/// @notice Contract that allows the treasury to define exchange rates between assets and facilitate swaps
contract DiscountSwapper is SanityCheckTrait, IDiscountSwapper {
    using SafeERC20 for IERC20;

    bytes32 public constant override contractType = "HELPER::DISCOUNT_SWAPPER";
    uint256 public constant override version = 3_10;

    /// @notice The address of the treasury
    address public immutable treasury;

    /// @notice The mapping of exchange rates between assets
    mapping(address => mapping(address => uint256)) public exchangeRates;

    /// @notice The mapping from market configurator addresses to allowed status
    mapping(address => bool) public allowedMarketConfigurator;

    /// @notice Precision for exchange rates
    uint256 public constant RATE_PRECISION = 1e18;

    modifier onlyTreasury() {
        require(msg.sender == treasury, "Only treasury can call this function");
        _;
    }

    /// @dev Checks whether the credit account is associated with an allowed market configurator
    modifier onlyCAFromAllowedMarketConfigurator(address creditAccount) {
        _checkMarketConfigurator(creditAccount);
        _;
    }

    /// @notice Constructor
    /// @param _treasury The address that will have the treasury role
    constructor(address _treasury) nonZeroAddress(_treasury) {
        treasury = _treasury;
    }

    /// @notice Swaps assetIn for assetOut based on the defined exchange rate
    /// @param assetIn The asset to send to the treasury
    /// @param assetOut The asset to receive from the treasury
    /// @param amountIn The amount of assetIn to swap
    /// @return amountOut The amount of assetOut received
    function swap(address assetIn, address assetOut, uint256 amountIn) external returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be greater than 0");

        uint256 rate = exchangeRates[assetIn][assetOut];
        require(rate > 0, "Exchange rate not set");

        // Calculate the amount of asset1 to receive
        amountOut = (amountIn * rate) / RATE_PRECISION;
        require(amountOut > 0, "Resulting amount too small");

        IERC20(assetIn).safeTransferFrom(msg.sender, treasury, amountIn);
        IERC20(assetOut).safeTransferFrom(treasury, msg.sender, amountOut);

        emit SwapAsset(assetIn, assetOut, amountIn, amountOut, msg.sender);

        return amountOut;
    }

    /// @dev Checks whether the market configurator associated with the credit account is allowed
    function _checkMarketConfigurator(address creditAccount) internal view {
        address creditManager = ICreditAccountV3(creditAccount).creditManager();
        address creditConfgirator = ICreditManagerV3(creditManager).creditConfigurator();
        address marketConfigurator = Ownable(ACLTrait(creditConfgirator).acl()).owner();

        if (!allowedMarketConfigurator[marketConfigurator]) revert MarketConfiguratorNotAllowedException();
    }

    /// @notice Sets the exchange rate between two assets
    /// @param assetIn The asset to send to the treasury
    /// @param assetOut The asset to receive from the treasury
    /// @param rate The exchange rate between the two assets (must be in the RATE_PRECISION format)
    function setExchangeRate(address assetIn, address assetOut, uint256 rate)
        external
        onlyTreasury
        nonZeroAddress(assetIn)
        nonZeroAddress(assetOut)
    {
        require(assetIn != assetOut, "Assets must be different");
        uint256 currentRate = exchangeRates[assetIn][assetOut];
        if (currentRate == rate) return;

        exchangeRates[assetIn][assetOut] = rate;
        emit SetExchangeRate(assetIn, assetOut, rate);
    }

    /// @notice Sets the allowed status of a market configurator
    /// @param marketConfigurator The address of the market configurator
    /// @param allowed The new status of the market configurator
    function setMarketConfiguratorStatus(address marketConfigurator, bool allowed)
        external
        onlyTreasury
        nonZeroAddress(marketConfigurator)
    {
        bool currentStatus = allowedMarketConfigurator[marketConfigurator];
        if (currentStatus == allowed) return;

        allowedMarketConfigurator[marketConfigurator] = allowed;
        emit SetMarketConfiguratorStatus(marketConfigurator, allowed);
    }
}
