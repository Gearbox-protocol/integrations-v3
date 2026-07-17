// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v3/contracts/test/mocks/token/ERC20Mock.sol";

import {MidasRedemptionVaultPhantomToken} from "../../../../helpers/midas/MidasRedemptionVaultPhantomToken.sol";

/// @dev Minimal gateway exposing only what the phantom token reads.
contract MidasGatewayMock {
    address public immutable mToken;
    address public immutable quoteToken;
    uint256 public pendingAmount;
    uint256 public claimableAmount;

    constructor(address _mToken, address _quoteToken) {
        mToken = _mToken;
        quoteToken = _quoteToken;
    }

    function setAmounts(uint256 pending, uint256 claimable) external {
        pendingAmount = pending;
        claimableAmount = claimable;
    }

    function pendingAndClaimableTokenOutAmounts(address) external view returns (uint256, uint256) {
        return (pendingAmount, claimableAmount);
    }
}

/// @title MidasRedemptionVaultPhantomToken unit test
/// @notice U:[MID-PT]: Unit tests for MidasRedemptionVaultPhantomToken
contract MidasRedemptionVaultPhantomTokenUnitTest is Test {
    MidasRedemptionVaultPhantomToken phantomToken;
    MidasGatewayMock gateway;

    address mToken;
    address quoteToken;

    function setUp() public {
        mToken = address(new ERC20Mock("mTBILL", "mTBILL", 18));
        quoteToken = address(new ERC20Mock("USD Coin", "USDC", 6));

        gateway = new MidasGatewayMock(mToken, quoteToken);
        phantomToken = new MidasRedemptionVaultPhantomToken(address(gateway), mToken, quoteToken);
    }

    /// @notice U:[MID-PT-1]: Constructor works as expected
    function test_U_MID_PT_01_constructor_works() public view {
        assertEq(phantomToken.contractType(), "PHANTOM_TOKEN::MIDAS_REDEMPTION", "Incorrect contract type");
        assertEq(phantomToken.version(), 3_11, "Incorrect version");
        assertEq(phantomToken.gateway(), address(gateway), "Incorrect gateway");
        assertEq(phantomToken.underlying(), quoteToken, "Incorrect underlying");
        assertEq(phantomToken.decimals(), 6, "Incorrect decimals");
        assertEq(phantomToken.name(), "mTBILL redeemed to USD Coin", "Incorrect name");
        assertEq(phantomToken.symbol(), "mTBILLrdUSDC", "Incorrect symbol");
    }

    /// @notice U:[MID-PT-2]: `balanceOf` returns pending + claimable amounts from the gateway
    function test_U_MID_PT_02_balanceOf_works() public {
        assertEq(phantomToken.balanceOf(makeAddr("ACCOUNT")), 0, "Should start at 0");

        gateway.setAmounts(40e6, 60e6);
        assertEq(phantomToken.balanceOf(makeAddr("ACCOUNT")), 100e6, "Incorrect balance");
    }

    /// @notice U:[MID-PT-3]: `getPhantomTokenInfo` and `serialize` work as expected
    function test_U_MID_PT_03_info_and_serialize_work() public view {
        (address gw, address underlying) = phantomToken.getPhantomTokenInfo();
        assertEq(gw, address(gateway), "Incorrect gateway from getPhantomTokenInfo");
        assertEq(underlying, quoteToken, "Incorrect underlying from getPhantomTokenInfo");

        (address sgw, address sunderlying) = abi.decode(phantomToken.serialize(), (address, address));
        assertEq(sgw, address(gateway), "Incorrect gateway in serialized data");
        assertEq(sunderlying, quoteToken, "Incorrect underlying in serialized data");
    }
}
