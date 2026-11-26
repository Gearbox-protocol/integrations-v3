// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasDepositVaultPhantomToken} from "../../../../integrations/midas/MidasDepositVaultPhantomToken.sol";

contract MidasDepositGatewayMockForPhantom {
    uint256 public pending;
    uint256 public claimable;

    function setAmounts(uint256 pending_, uint256 claimable_) external {
        pending = pending_;
        claimable = claimable_;
    }

    function pendingAndClaimableTokenOutAmounts(address) external view returns (uint256, uint256) {
        return (pending, claimable);
    }
}

/// @title MidasDepositVaultPhantomToken unit test
/// @notice U:[MID-DPT]: Unit tests for MidasDepositVaultPhantomToken
contract MidasDepositVaultPhantomTokenUnitTest is Test {
    MidasDepositVaultPhantomToken phantomToken;
    MidasDepositGatewayMockForPhantom gateway;

    address mToken;
    address tokenIn;

    function setUp() public {
        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        tokenIn = address(new ERC20Mock("USDC", "USDC", 6));
        gateway = new MidasDepositGatewayMockForPhantom();
        phantomToken = new MidasDepositVaultPhantomToken(address(gateway), mToken, tokenIn);
    }

    /// @notice U:[MID-DPT-1]: Constructor works as expected
    function test_U_MID_DPT_01_constructor_works() public view {
        assertEq(phantomToken.contractType(), "PHANTOM_TOKEN::MIDAS_DEPOSIT", "Incorrect contract type");
        assertEq(phantomToken.version(), 3_10, "Incorrect version");
        assertEq(phantomToken.gateway(), address(gateway), "Incorrect gateway");
        assertEq(phantomToken.underlying(), mToken, "Incorrect underlying");
        assertEq(phantomToken.decimals(), 18, "Incorrect decimals");
        assertEq(phantomToken.name(), "USDC deposited to mTBILL", "Incorrect name");
        assertEq(phantomToken.symbol(), "USDCdpmTBILL", "Incorrect symbol");

        (address gw, address underlying) = phantomToken.getPhantomTokenInfo();
        assertEq(gw, address(gateway), "Incorrect gateway from getPhantomTokenInfo");
        assertEq(underlying, mToken, "Incorrect underlying from getPhantomTokenInfo");
    }

    /// @notice U:[MID-DPT-2]: `balanceOf` sums pending and claimable amounts
    function test_U_MID_DPT_02_balanceOf_sums_pending_and_claimable() public {
        address account = makeAddr("ACCOUNT");
        gateway.setAmounts(40e18, 60e18);
        assertEq(phantomToken.balanceOf(account), 100e18, "Incorrect balance");
    }
}
