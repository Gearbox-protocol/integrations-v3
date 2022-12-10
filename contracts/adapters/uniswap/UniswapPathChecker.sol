// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Path } from "../../integrations/uniswap/Path.sol";

/// @dev The length of the bytes encoded address
uint256 constant ADDR_SIZE = 20;

/// @dev The length of the uint24 encoded address
uint256 constant FEE_SIZE = 3;

/// @dev Minimal path length in bytes
uint256 constant MIN_PATH_LENGTH = 2 * ADDR_SIZE + FEE_SIZE;

/// @dev Number of bytes in path per single token
uint256 constant ADDR_PLUS_FEE_LENGTH = ADDR_SIZE + FEE_SIZE;

/// @dev Maximal allowed path length in bytes (3 hops)
uint256 constant MAX_PATH_LENGTH = 4 * ADDR_SIZE + 3 * FEE_SIZE;

contract UniswapPathChecker {
    using Path for bytes;

    address public immutable connectorToken0;
    address public immutable connectorToken1;
    address public immutable connectorToken2;
    address public immutable connectorToken3;
    address public immutable connectorToken4;
    address public immutable connectorToken5;
    address public immutable connectorToken6;
    address public immutable connectorToken7;
    address public immutable connectorToken8;
    address public immutable connectorToken9;

    constructor(address[] memory _connectorTokensInit) {
        address[10] memory _connectorTokens;
        uint256 len = _connectorTokensInit.length;

        for (uint256 i = 0; i < 10; ++i) {
            _connectorTokens[i] = i >= len
                ? address(0)
                : _connectorTokensInit[i];
        }

        connectorToken0 = _connectorTokens[0];
        connectorToken1 = _connectorTokens[1];
        connectorToken2 = _connectorTokens[2];
        connectorToken3 = _connectorTokens[3];
        connectorToken4 = _connectorTokens[4];
        connectorToken5 = _connectorTokens[5];
        connectorToken6 = _connectorTokens[6];
        connectorToken7 = _connectorTokens[7];
        connectorToken8 = _connectorTokens[8];
        connectorToken9 = _connectorTokens[9];
    }

    function isConnector(address token) public view returns (bool) {
        return
            token == connectorToken0 ||
            token == connectorToken1 ||
            token == connectorToken2 ||
            token == connectorToken3 ||
            token == connectorToken4 ||
            token == connectorToken5 ||
            token == connectorToken6 ||
            token == connectorToken7 ||
            token == connectorToken8 ||
            token == connectorToken9;
    }

    function parseUniV2Path(address[] memory path)
        external
        view
        returns (
            bool valid,
            address tokenIn,
            address tokenOut
        )
    {
        valid = true;
        tokenIn = path[0];
        tokenOut = path[path.length - 1];

        uint256 len = path.length;

        if (len > 4) {
            valid = false;
        }

        for (uint256 i = 1; i < len - 1; ) {
            if (!isConnector(path[i])) {
                valid = false;
            }

            unchecked {
                ++i;
            }
        }
    }

    function parseUniV3Path(bytes memory path)
        external
        view
        returns (
            bool valid,
            address tokenIn,
            address tokenOut
        )
    {
        valid = true;

        if (path.length < MIN_PATH_LENGTH || path.length > MAX_PATH_LENGTH)
            valid = false;

        (tokenIn, , ) = path.decodeFirstPool();

        while (path.hasMultiplePools()) {
            (, address midToken, ) = path.decodeFirstPool();

            if (!isConnector(midToken)) {
                valid = false;
            }

            path = path.skipToken();
        }

        (, tokenOut, ) = path.decodeFirstPool();
    }
}
