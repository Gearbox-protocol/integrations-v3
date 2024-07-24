// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

import {IAsset, PoolSpecialization} from "../../../../integrations/balancer/IBalancerV2Vault.sol";

contract VaultMock {
    struct PoolData {
        address bpt;
        IAsset[] tokens;
    }

    mapping(bytes32 => PoolData) internal _poolData;

    function getPool(bytes32 poolId) external view returns (address, PoolSpecialization) {
        return (_poolData[poolId].bpt, PoolSpecialization.GENERAL);
    }

    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (IAsset[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock)
    {
        tokens = _poolData[poolId].tokens;
        balances = new uint256[](0);
        lastChangeBlock = 0;
    }

    function setPoolData(bytes32 poolId, address bpt, IAsset[] memory tokens) external {
        _poolData[poolId] = PoolData(bpt, tokens);
    }
}
