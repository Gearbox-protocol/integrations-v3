pragma solidity ^0.8.10;

import { Tokens } from "./Tokens.sol";
import { Contracts } from "./SupportedContracts.sol";

/// @dev A struct containing parameters for a recognized collateral token in the system
struct CollateralTokenHuman {
    /// @dev Address of the collateral token
    Tokens token;
    /// @dev Address of the liquidation threshold
    uint16 liquidationThreshold;
}

/// @dev A struct representing the initial Credit Manager configuration parameters
struct CreditManagerHumanOpts {
    /// @dev The minimal debt principal amount
    uint128 minBorrowedAmount;
    /// @dev The maximal debt principal amount
    uint128 maxBorrowedAmount;
    /// @dev The initial list of collateral tokens to allow
    CollateralTokenHuman[] collateralTokens;
    /// @dev Address of DegenNFT, address(0) if whitelisted mode is not used
    address degenNFT;
    /// @dev Whether the Credit Manager is connected to an expirable pool (and the CreditFacade is expirable)
    bool expirable;
    /// @dev Contracts which should become adapters
    Contracts[] contracts;
}

contract CreditConfigLive {
    mapping(Tokens => CreditManagerHumanOpts) creditManagerHumanOpts;

    constructor() {
        CreditManagerHumanOpts storage cm;

        // $CREDIT_MANAGER_CONFIG
    }
}
