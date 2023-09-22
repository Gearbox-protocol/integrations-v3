/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../common";
import type { LiveEnvHelper, LiveEnvHelperInterface } from "../LiveEnvHelper";

const _abi = [
  {
    inputs: [],
    name: "MAINNET_CONFIGURATOR",
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
    inputs: [],
    name: "_setUp",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "supportedContracts",
    outputs: [
      {
        internalType: "contract SupportedContracts",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "tokenTestSuite",
    outputs: [
      {
        internalType: "contract TokensTestSuite",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;

const _bytecode =

type LiveEnvHelperConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: LiveEnvHelperConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class LiveEnvHelper__factory extends ContractFactory {
  constructor(...args: LiveEnvHelperConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "LiveEnvHelper";
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<LiveEnvHelper> {
    return super.deploy(overrides || {}) as Promise<LiveEnvHelper>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): LiveEnvHelper {
    return super.attach(address) as LiveEnvHelper;
  }
  override connect(signer: Signer): LiveEnvHelper__factory {
    return super.connect(signer) as LiveEnvHelper__factory;
  }
  static readonly contractName: "LiveEnvHelper";

  public readonly contractName: "LiveEnvHelper";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): LiveEnvHelperInterface {
    return new utils.Interface(_abi) as LiveEnvHelperInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): LiveEnvHelper {
    return new Contract(address, _abi, signerOrProvider) as LiveEnvHelper;
  }
}