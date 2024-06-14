// SPDX-License-Identifier: MIT
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023
pragma solidity ^0.8.17;

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

import {IZircuitPoolAdapter} from "../../../interfaces/zircuit/IZircuitPoolAdapter.sol";

interface ZircuitPoolMulticaller {}

library ZircuitPoolCalls {
    function depositFor(ZircuitPoolMulticaller c, address _token, address _for, uint256 _amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IZircuitPoolAdapter.depositFor, (_token, _for, _amount))
        });
    }

    function depositDiff(ZircuitPoolMulticaller c, address _token, uint256 _leftoverAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IZircuitPoolAdapter.depositDiff, (_token, _leftoverAmount))
        });
    }

    function withdraw(ZircuitPoolMulticaller c, address _token, uint256 _amount)
        internal
        pure
        returns (MultiCall memory)
    {
        return
            MultiCall({target: address(c), callData: abi.encodeCall(IZircuitPoolAdapter.withdraw, (_token, _amount))});
    }

    function withdrawDiff(ZircuitPoolMulticaller c, address _token, uint256 _leftoverAmount)
        internal
        pure
        returns (MultiCall memory)
    {
        return MultiCall({
            target: address(c),
            callData: abi.encodeCall(IZircuitPoolAdapter.withdrawDiff, (_token, _leftoverAmount))
        });
    }
}
