/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../common";
import type {
  LiveEnvTestSuite,
  LiveEnvTestSuiteInterface,
} from "../LiveEnvTestSuite";

const _abi = [
  {
    inputs: [],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "ROOT_ADDRESS",
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
        internalType: "enum Tokens",
        name: "",
        type: "uint8",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "_creditConfigurators",
    outputs: [
      {
        internalType: "contract CreditConfigurator",
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
        internalType: "enum Tokens",
        name: "",
        type: "uint8",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "_creditFacades",
    outputs: [
      {
        internalType: "contract CreditFacade",
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
        internalType: "enum Tokens",
        name: "",
        type: "uint8",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "_creditManagers",
    outputs: [
      {
        internalType: "contract CreditManager",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "acl",
    outputs: [
      {
        internalType: "contract ACL",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "activeCM",
    outputs: [
      {
        internalType: "contract CreditManager",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "addressProvider",
    outputs: [
      {
        internalType: "contract AddressProvider",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "blacklistHelper",
    outputs: [
      {
        internalType: "contract BlacklistHelper",
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
        internalType: "enum Tokens",
        name: "",
        type: "uint8",
      },
    ],
    name: "creditConfiguratorMocks",
    outputs: [
      {
        internalType: "contract CreditConfigurator",
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
        internalType: "enum Tokens",
        name: "t",
        type: "uint8",
      },
    ],
    name: "creditConfigurators",
    outputs: [
      {
        internalType: "contract CreditConfigurator",
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
        internalType: "enum Tokens",
        name: "t",
        type: "uint8",
      },
      {
        internalType: "uint256",
        name: "idx",
        type: "uint256",
      },
    ],
    name: "creditConfigurators",
    outputs: [
      {
        internalType: "contract CreditConfigurator",
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
        internalType: "enum Tokens",
        name: "",
        type: "uint8",
      },
    ],
    name: "creditFacadeMocks",
    outputs: [
      {
        internalType: "contract CreditFacade",
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
        internalType: "enum Tokens",
        name: "t",
        type: "uint8",
      },
      {
        internalType: "uint256",
        name: "idx",
        type: "uint256",
      },
    ],
    name: "creditFacades",
    outputs: [
      {
        internalType: "contract CreditFacade",
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
        internalType: "enum Tokens",
        name: "t",
        type: "uint8",
      },
    ],
    name: "creditFacades",
    outputs: [
      {
        internalType: "contract CreditFacade",
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
        internalType: "enum Tokens",
        name: "",
        type: "uint8",
      },
    ],
    name: "creditManagerMocks",
    outputs: [
      {
        internalType: "contract CreditManagerLiveMock",
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
        internalType: "enum Tokens",
        name: "t",
        type: "uint8",
      },
      {
        internalType: "uint256",
        name: "idx",
        type: "uint256",
      },
    ],
    name: "creditManagers",
    outputs: [
      {
        internalType: "contract CreditManager",
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
        internalType: "enum Tokens",
        name: "t",
        type: "uint8",
      },
    ],
    name: "creditManagers",
    outputs: [
      {
        internalType: "contract CreditManager",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "degenNFT",
    outputs: [
      {
        internalType: "contract DegenNFT",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getActiveCM",
    outputs: [
      {
        internalType: "contract CreditManager",
        name: "cm",
        type: "address",
      },
      {
        internalType: "contract CreditFacade",
        name: "cf",
        type: "address",
      },
      {
        internalType: "contract CreditConfigurator",
        name: "cc",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "accountAmount",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "enum Tokens",
        name: "underlying",
        type: "uint8",
      },
      {
        internalType: "enum Contracts",
        name: "target",
        type: "uint8",
      },
      {
        internalType: "uint256",
        name: "cmIdx",
        type: "uint256",
      },
    ],
    name: "getAdapter",
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
        name: "creditManager",
        type: "address",
      },
      {
        internalType: "enum Contracts",
        name: "target",
        type: "uint8",
      },
    ],
    name: "getAdapter",
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
        internalType: "enum Tokens",
        name: "underlying",
        type: "uint8",
      },
      {
        internalType: "enum Contracts",
        name: "target",
        type: "uint8",
      },
    ],
    name: "getAdapter",
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
        internalType: "enum Tokens",
        name: "underlying",
        type: "uint8",
      },
      {
        internalType: "uint256",
        name: "cmIdx",
        type: "uint256",
      },
    ],
    name: "getAdapters",
    outputs: [
      {
        internalType: "address[]",
        name: "adapters",
        type: "address[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "enum Tokens",
        name: "underlying",
        type: "uint8",
      },
    ],
    name: "getAdapters",
    outputs: [
      {
        internalType: "address[]",
        name: "adapters",
        type: "address[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "creditManager",
        type: "address",
      },
    ],
    name: "getAdapters",
    outputs: [
      {
        internalType: "address[]",
        name: "adapters",
        type: "address[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getBalances",
    outputs: [
      {
        components: [
          {
            internalType: "address",
            name: "token",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "balance",
            type: "uint256",
          },
        ],
        internalType: "struct Balance[]",
        name: "balances",
        type: "tuple[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "enum Tokens",
        name: "underlying",
        type: "uint8",
      },
      {
        internalType: "enum Contracts",
        name: "target",
        type: "uint8",
      },
    ],
    name: "getMockAdapter",
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
    name: "getSupportedUnderlyings",
    outputs: [
      {
        internalType: "enum Tokens[]",
        name: "",
        type: "uint8[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "enum Tokens",
        name: "",
        type: "uint8",
      },
    ],
    name: "pools",
    outputs: [
      {
        internalType: "contract PoolService",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "priceOracle",
    outputs: [
      {
        internalType: "contract PriceOracle",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
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

type LiveEnvTestSuiteConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: LiveEnvTestSuiteConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class LiveEnvTestSuite__factory extends ContractFactory {
  constructor(...args: LiveEnvTestSuiteConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "LiveEnvTestSuite";
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<LiveEnvTestSuite> {
    return super.deploy(overrides || {}) as Promise<LiveEnvTestSuite>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): LiveEnvTestSuite {
    return super.attach(address) as LiveEnvTestSuite;
  }
  override connect(signer: Signer): LiveEnvTestSuite__factory {
    return super.connect(signer) as LiveEnvTestSuite__factory;
  }
  static readonly contractName: "LiveEnvTestSuite";

  public readonly contractName: "LiveEnvTestSuite";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): LiveEnvTestSuiteInterface {
    return new utils.Interface(_abi) as LiveEnvTestSuiteInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): LiveEnvTestSuite {
    return new Contract(address, _abi, signerOrProvider) as LiveEnvTestSuite;
  }
}