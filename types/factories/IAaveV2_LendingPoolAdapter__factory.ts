/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type {
  IAaveV2_LendingPoolAdapter,
  IAaveV2_LendingPoolAdapterInterface,
} from "../IAaveV2_LendingPoolAdapter";

const _abi = [
  {
    inputs: [],
    name: "CallerNotConfiguratorException",
    type: "error",
  },
  {
    inputs: [],
    name: "CreditFacadeOnlyException",
    type: "error",
  },
  {
    inputs: [],
    name: "TokenNotAllowedException",
    type: "error",
  },
  {
    inputs: [],
    name: "_acl",
    outputs: [
      {
        internalType: "contract IACL",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "_gearboxAdapterType",
    outputs: [
      {
        internalType: "enum AdapterType",
        name: "",
        type: "uint8",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [],
    name: "_gearboxAdapterVersion",
    outputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [],
    name: "addressProvider",
    outputs: [
      {
        internalType: "contract IAddressProvider",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "creditManager",
    outputs: [
      {
        internalType: "contract ICreditManagerV2",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "asset",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    name: "deposit",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "asset",
        type: "address",
      },
    ],
    name: "depositAll",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "targetContract",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "asset",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "withdraw",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "asset",
        type: "address",
      },
    ],
    name: "withdrawAll",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

export class IAaveV2_LendingPoolAdapter__factory {
  static readonly abi = _abi;
  static createInterface(): IAaveV2_LendingPoolAdapterInterface {
    return new utils.Interface(_abi) as IAaveV2_LendingPoolAdapterInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IAaveV2_LendingPoolAdapter {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as IAaveV2_LendingPoolAdapter;
  }
}