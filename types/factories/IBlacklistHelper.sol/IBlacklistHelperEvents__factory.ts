/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type {
  IBlacklistHelperEvents,
  IBlacklistHelperEventsInterface,
} from "../../IBlacklistHelper.sol/IBlacklistHelperEvents";

const _abi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "underlying",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "holder",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "ClaimableAdded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "underlying",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "holder",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "Claimed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "creditFacade",
        type: "address",
      },
    ],
    name: "CreditFacadeAdded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "creditFacade",
        type: "address",
      },
    ],
    name: "CreditFacadeRemoved",
    type: "event",
  },
] as const;

export class IBlacklistHelperEvents__factory {
  static readonly abi = _abi;
  static createInterface(): IBlacklistHelperEventsInterface {
    return new utils.Interface(_abi) as IBlacklistHelperEventsInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IBlacklistHelperEvents {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as IBlacklistHelperEvents;
  }
}