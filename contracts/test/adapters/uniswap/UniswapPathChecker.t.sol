// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { UniswapPathChecker } from "../../../adapters/uniswap/UniswapPathChecker.sol";

// TEST
import "../../lib/constants.sol";
import { AdapterTestHelper } from "../AdapterTestHelper.sol";
import { Tokens } from "../../suites/TokensTestSuite.sol";
import { BytesLib } from "../../../integrations/uniswap/BytesLib.sol";

contract UniswapPathCheckerTest is AdapterTestHelper {
    using BytesLib for bytes;

    UniswapPathChecker pathChecker;

    function setUp() public {
        _setUp();
        address[] memory tokens = new address[](2);

        tokens[0] = tokenTestSuite.addressOf(Tokens.USDC);
        tokens[1] = tokenTestSuite.addressOf(Tokens.USDT);

        pathChecker = new UniswapPathChecker(tokens);
    }

    function test_UPC_01_constructor_sets_correct_values() public {
        assertEq(
            pathChecker.connectorToken0(),
            tokenTestSuite.addressOf(Tokens.USDC),
            "Connector token 0 is incorrect"
        );

        assertEq(
            pathChecker.connectorToken1(),
            tokenTestSuite.addressOf(Tokens.USDT),
            "Connector token 1 is incorrect"
        );

        assertEq(
            pathChecker.connectorToken2(),
            address(0),
            "Connector token 2 is incorrect"
        );

        assertEq(
            pathChecker.connectorToken3(),
            address(0),
            "Connector token 3 is incorrect"
        );
        assertEq(
            pathChecker.connectorToken4(),
            address(0),
            "Connector token 4 is incorrect"
        );
        assertEq(
            pathChecker.connectorToken5(),
            address(0),
            "Connector token 5 is incorrect"
        );
        assertEq(
            pathChecker.connectorToken6(),
            address(0),
            "Connector token 6 is incorrect"
        );
        assertEq(
            pathChecker.connectorToken7(),
            address(0),
            "Connector token 7 is incorrect"
        );
        assertEq(
            pathChecker.connectorToken8(),
            address(0),
            "Connector token 8 is incorrect"
        );
        assertEq(
            pathChecker.connectorToken9(),
            address(0),
            "Connector token 9 is incorrect"
        );
    }

    function test_UPC_02_isConnector_works_correctly() public {
        assertTrue(
            pathChecker.isConnector(tokenTestSuite.addressOf(Tokens.USDC)),
            "Connector token not added"
        );

        assertTrue(
            pathChecker.isConnector(tokenTestSuite.addressOf(Tokens.USDT)),
            "Connector token not added"
        );

        assertTrue(
            !pathChecker.isConnector(DUMB_ADDRESS),
            "Non-connector token was added"
        );
    }

    function test_UPC_03_parseUniV2Path_works_correctly() public {
        address[] memory path = new address[](5);
        path[0] = creditManager.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.USDC);
        path[2] = tokenTestSuite.addressOf(Tokens.USDT);
        path[3] = tokenTestSuite.addressOf(Tokens.USDC);
        path[4] = tokenTestSuite.addressOf(Tokens.WETH);

        (bool valid, address tokenIn, address tokenOut) = pathChecker
            .parseUniV2Path(path);

        assertTrue(!valid, "Invalid path marked as valid");

        assertEq(tokenIn, creditManager.underlying(), "Invalid tokenIn");

        assertEq(
            tokenOut,
            tokenTestSuite.addressOf(Tokens.WETH),
            "Invalid tokenOut"
        );

        path = new address[](3);
        path[0] = creditManager.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.LINK);
        path[2] = tokenTestSuite.addressOf(Tokens.WETH);

        (valid, tokenIn, tokenOut) = pathChecker.parseUniV2Path(path);

        assertTrue(!valid, "Invalid path marked as valid");

        assertEq(tokenIn, creditManager.underlying(), "Invalid tokenIn");

        assertEq(
            tokenOut,
            tokenTestSuite.addressOf(Tokens.WETH),
            "Invalid tokenOut"
        );

        path = new address[](3);
        path[0] = creditManager.underlying();
        path[1] = tokenTestSuite.addressOf(Tokens.USDC);
        path[2] = tokenTestSuite.addressOf(Tokens.WETH);

        (valid, tokenIn, tokenOut) = pathChecker.parseUniV2Path(path);

        assertTrue(valid, "Valid path marked as invalid");

        assertEq(tokenIn, creditManager.underlying(), "Invalid tokenIn");

        assertEq(
            tokenOut,
            tokenTestSuite.addressOf(Tokens.WETH),
            "Invalid tokenOut"
        );
    }

    function test_UPC_04_parseUniV3Path_works_correctly() public {
        bytes memory path = bytes(abi.encodePacked(creditManager.underlying()))
            .concat(bytes(abi.encodePacked(uint24(3000))))
            .concat(
                bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC)))
            )
            .concat(bytes(abi.encodePacked(uint24(3000))))
            .concat(
                bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDT)))
            )
            .concat(bytes(abi.encodePacked(uint24(3000))))
            .concat(
                bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC)))
            )
            .concat(bytes(abi.encodePacked(uint24(3000))))
            .concat(
                bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH)))
            );

        (bool valid, address tokenIn, address tokenOut) = pathChecker
            .parseUniV3Path(path);

        assertTrue(!valid, "Invalid path marked as valid");

        assertEq(tokenIn, creditManager.underlying(), "Invalid tokenIn");

        assertEq(
            tokenOut,
            tokenTestSuite.addressOf(Tokens.WETH),
            "Invalid tokenOut"
        );

        path = bytes(abi.encodePacked(creditManager.underlying()))
            .concat(bytes(abi.encodePacked(uint24(3000))))
            .concat(
                bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.LINK)))
            )
            .concat(bytes(abi.encodePacked(uint24(3000))))
            .concat(
                bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH)))
            );

        (valid, tokenIn, tokenOut) = pathChecker.parseUniV3Path(path);

        assertTrue(!valid, "Invalid path marked as valid");

        assertEq(tokenIn, creditManager.underlying(), "Invalid tokenIn");

        assertEq(
            tokenOut,
            tokenTestSuite.addressOf(Tokens.WETH),
            "Invalid tokenOut"
        );

        path = bytes(abi.encodePacked(creditManager.underlying()))
            .concat(bytes(abi.encodePacked(uint24(3000))))
            .concat(
                bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.USDC)))
            )
            .concat(bytes(abi.encodePacked(uint24(3000))))
            .concat(
                bytes(abi.encodePacked(tokenTestSuite.addressOf(Tokens.WETH)))
            );

        (valid, tokenIn, tokenOut) = pathChecker.parseUniV3Path(path);

        assertTrue(valid, "Valid path marked as invalid");

        assertEq(tokenIn, creditManager.underlying(), "Invalid tokenIn");

        assertEq(
            tokenOut,
            tokenTestSuite.addressOf(Tokens.WETH),
            "Invalid tokenOut"
        );
    }
}
