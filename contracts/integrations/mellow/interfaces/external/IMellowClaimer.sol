// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IMellowClaimer {
    function multiAcceptAndClaim(
        address multiVault,
        uint256[] calldata subvaultIndices,
        uint256[][] calldata indices,
        address recipient,
        uint256 maxAssets
    ) external returns (uint256 assets);
}
