/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../common";
import type {
  CompoundPriceFeed,
  CompoundPriceFeedInterface,
} from "../CompoundPriceFeed";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "addressProvider",
        type: "address",
      },
      {
        internalType: "address",
        name: "_cToken",
        type: "address",
      },
      {
        internalType: "address",
        name: "_priceFeed",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "CallerNotConfiguratorException",
    type: "error",
  },
  {
    inputs: [],
    name: "CallerNotControllerException",
    type: "error",
  },
  {
    inputs: [],
    name: "CallerNotPausableAdminException",
    type: "error",
  },
  {
    inputs: [],
    name: "CallerNotUnPausableAdminException",
    type: "error",
  },
  {
    inputs: [],
    name: "ChainPriceStaleException",
    type: "error",
  },
  {
    inputs: [],
    name: "IncorrectLimitsException",
    type: "error",
  },
  {
    inputs: [],
    name: "NotImplementedException",
    type: "error",
  },
  {
    inputs: [],
    name: "PriceOracleNotExistsException",
    type: "error",
  },
  {
    inputs: [],
    name: "ValueOutOfRangeException",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroAddressException",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroPriceException",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "newController",
        type: "address",
      },
    ],
    name: "NewController",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "lowerBound",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "upperBound",
        type: "uint256",
      },
    ],
    name: "NewLimiterParams",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Paused",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Unpaused",
    type: "event",
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
    name: "cToken",
    outputs: [
      {
        internalType: "contract ICToken",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "controller",
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
    name: "decimals",
    outputs: [
      {
        internalType: "uint8",
        name: "",
        type: "uint8",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "decimalsDivider",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "delta",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "description",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "externalController",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint80",
        name: "",
        type: "uint80",
      },
    ],
    name: "getRoundData",
    outputs: [
      {
        internalType: "uint80",
        name: "",
        type: "uint80",
      },
      {
        internalType: "int256",
        name: "",
        type: "int256",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "uint80",
        name: "",
        type: "uint80",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [],
    name: "latestRoundData",
    outputs: [
      {
        internalType: "uint80",
        name: "roundId",
        type: "uint80",
      },
      {
        internalType: "int256",
        name: "answer",
        type: "int256",
      },
      {
        internalType: "uint256",
        name: "startedAt",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "updatedAt",
        type: "uint256",
      },
      {
        internalType: "uint80",
        name: "answeredInRound",
        type: "uint80",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "lowerBound",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "pause",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "paused",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "priceFeed",
    outputs: [
      {
        internalType: "contract AggregatorV3Interface",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "priceFeedType",
    outputs: [
      {
        internalType: "enum PriceFeedType",
        name: "",
        type: "uint8",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newController",
        type: "address",
      },
    ],
    name: "setController",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_lowerBound",
        type: "uint256",
      },
    ],
    name: "setLimiter",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "skipPriceCheck",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "unpause",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "upperBound",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "version",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;

const _bytecode =
  "0x6101006040526000805460ff60b01b1916600160b01b1790553480156200002557600080fd5b5060405162001baf38038062001baf8339810160408190526200004891620004f4565b8260c86001600160a01b038416620000705760405180602001604052806000815250620000fb565b836001600160a01b03166306fdde036040518163ffffffff1660e01b8152600401600060405180830381865afa158015620000af573d6000803e3d6000fd5b505050506040513d6000823e601f3d908101601f19168201604052620000d991908101906200057a565b604051602001620000eb919062000632565b6040516020818303038152906040525b6000805460ff19169055826001600160a01b0381166200012e57604051635919af9760e11b815260040160405180910390fd5b806001600160a01b031663087376956040518163ffffffff1660e01b8152600401602060405180830381865afa1580156200016d573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019062000193919062000662565b6001600160a01b03166080816001600160a01b031681525050806001600160a01b031663087376956040518163ffffffff1660e01b8152600401602060405180830381865afa158015620001eb573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019062000211919062000662565b6001600160a01b0316638da5cb5b6040518163ffffffff1660e01b8152600401602060405180830381865afa1580156200024f573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019062000275919062000662565b600080546001600160a01b039290921661010002610100600160a81b0319909216919091179055506002620002ab828262000716565b505060a052506001600160a01b0382161580620002cf57506001600160a01b038116155b15620002ee57604051635919af9760e11b815260040160405180910390fd5b6001600160a01b0380831660e081905290821660c0526040805163bd6d894d60e01b815290516000929163bd6d894d916004808301926020929190829003018187875af115801562000344573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906200036a9190620007e2565b9050620003778162000381565b5050505062000865565b801580620003a25750620003a0816200039a816200040e565b62000442565b155b15620003c1576040516309aadd6f60e41b815260040160405180910390fd5b60018190557f82e7ee47180a631312683eeb2a85ad264c9af490d54de5a75bbdb95b968c6de281620003f3816200040e565b6040805192835260208301919091520160405180910390a150565b60a0516000906127109062000424908262000812565b62000430908462000828565b6200043c919062000842565b92915050565b60008060e0516001600160a01b031663182df0f56040518163ffffffff1660e01b8152600401602060405180830381865afa15801562000486573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190620004ac9190620007e2565b905083811080620004bc57508281115b15620004cd5760009150506200043c565b5060019392505050565b80516001600160a01b0381168114620004ef57600080fd5b919050565b6000806000606084860312156200050a57600080fd5b6200051584620004d7565b92506200052560208501620004d7565b91506200053560408501620004d7565b90509250925092565b634e487b7160e01b600052604160045260246000fd5b60005b838110156200057157818101518382015260200162000557565b50506000910152565b6000602082840312156200058d57600080fd5b81516001600160401b0380821115620005a557600080fd5b818401915084601f830112620005ba57600080fd5b815181811115620005cf57620005cf6200053e565b604051601f8201601f19908116603f01168101908382118183101715620005fa57620005fa6200053e565b816040528281528760208487010111156200061457600080fd5b6200062783602083016020880162000554565b979650505050505050565b600082516200064681846020870162000554565b69081c1c9a58d95199595960b21b920191825250600a01919050565b6000602082840312156200067557600080fd5b6200068082620004d7565b9392505050565b600181811c908216806200069c57607f821691505b602082108103620006bd57634e487b7160e01b600052602260045260246000fd5b50919050565b601f8211156200071157600081815260208120601f850160051c81016020861015620006ec5750805b601f850160051c820191505b818110156200070d57828155600101620006f8565b5050505b505050565b81516001600160401b038111156200073257620007326200053e565b6200074a8162000743845462000687565b84620006c3565b602080601f831160018114620007825760008415620007695750858301515b600019600386901b1c1916600185901b1785556200070d565b600085815260208120601f198616915b82811015620007b35788860151825594840194600190910190840162000792565b5085821015620007d25787850151600019600388901b60f8161c191681555b5050505050600190811b01905550565b600060208284031215620007f557600080fd5b5051919050565b634e487b7160e01b600052601160045260246000fd5b808201808211156200043c576200043c620007fc565b80820281158282048414176200043c576200043c620007fc565b6000826200086057634e487b7160e01b600052601260045260246000fd5b500490565b60805160a05160c05160e0516112d1620008de6000396000818161023d01528181610ad20152610f3401526000818161029e0152610a290152600081816101810152610c75015260008181610333015281816103e20152818161055e0152818161064a01528181610745015261095d01526112d16000f3fe608060405234801561001057600080fd5b50600436106101775760003560e01c80638456cb59116100d8578063a834559e1161008c578063d62ada1111610066578063d62ada111461037f578063f77c479114610387578063feaf968c146103ac57600080fd5b8063a834559e14610355578063b09ad8a014610364578063bc489a651461036c57600080fd5b80639a6fc8f5116100bd5780639a6fc8f5146102db578063a384d6ff14610325578063a50cf2c81461032e57600080fd5b80638456cb59146102c057806392eefe9b146102c857600080fd5b806354fd4d501161012f57806369e527da1161011457806369e527da146102385780637284e41614610284578063741bef1a1461029957600080fd5b806354fd4d50146102255780635c975abb1461022d57600080fd5b8063313ce56711610160578063313ce567146101ec5780633f4ba83a146102065780633fd0875f1461021057600080fd5b806312b495a81461017c57806325e22370146101b6575b600080fd5b6101a37f000000000000000000000000000000000000000000000000000000000000000081565b6040519081526020015b60405180910390f35b6000546101dc907501000000000000000000000000000000000000000000900460ff1681565b60405190151581526020016101ad565b6101f4600881565b60405160ff90911681526020016101ad565b61020e6103b4565b005b610218600a81565b6040516101ad9190610fe9565b6101a3600181565b60005460ff166101dc565b61025f7f000000000000000000000000000000000000000000000000000000000000000081565b60405173ffffffffffffffffffffffffffffffffffffffff90911681526020016101ad565b61028c6104a2565b6040516101ad919061102a565b61025f7f000000000000000000000000000000000000000000000000000000000000000081565b61020e610530565b61020e6102d6366004611096565b61061c565b6102ee6102e93660046110eb565b610864565b6040805169ffffffffffffffffffff968716815260208101959095528401929092526060830152909116608082015260a0016101ad565b6101a360015481565b61025f7f000000000000000000000000000000000000000000000000000000000000000081565b6101a3670de0b6b3a764000081565b6101a361089e565b61020e61037a366004611108565b6108b0565b6101dc600181565b60005461025f90610100900473ffffffffffffffffffffffffffffffffffffffff1681565b6102ee610a1f565b6040517fd4eb5db00000000000000000000000000000000000000000000000000000000081523360048201527f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff169063d4eb5db090602401602060405180830381865afa15801561043e573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906104629190611121565b610498576040517f10332dee00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6104a0610b93565b565b600280546104af90611143565b80601f01602080910402602001604051908101604052809291908181526020018280546104db90611143565b80156105285780601f106104fd57610100808354040283529160200191610528565b820191906000526020600020905b81548152906001019060200180831161050b57829003601f168201915b505050505081565b6040517f3a41ec640000000000000000000000000000000000000000000000000000000081523360048201527f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1690633a41ec6490602401602060405180830381865afa1580156105ba573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906105de9190611121565b610614576040517fd794b1e700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6104a0610c10565b6040517f5f259aba0000000000000000000000000000000000000000000000000000000081523360048201527f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1690635f259aba90602401602060405180830381865afa1580156106a6573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906106ca9190611121565b610700576040517f61081c1500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6040517f5f259aba00000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff82811660048301527f00000000000000000000000000000000000000000000000000000000000000001690635f259aba90602401602060405180830381865afa15801561078c573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906107b09190611121565b600080547fffffffffffffffffffff000000000000000000000000000000000000000000ff1691157501000000000000000000000000000000000000000000027fffffffffffffffffffffff0000000000000000000000000000000000000000ff169190911761010073ffffffffffffffffffffffffffffffffffffffff841690810291909117825560405190917fe253457d9ad994ca9682fc3bbc38c890dca73a2d5ecee3809e548bac8b00d7c691a250565b60008060008060006040517f24e46f7000000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60006108ab600154610c6b565b905090565b6000547501000000000000000000000000000000000000000000900460ff161561092f57600054610100900473ffffffffffffffffffffffffffffffffffffffff16331461092a576040517f0129bb9900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610a13565b6040517f5f259aba0000000000000000000000000000000000000000000000000000000081523360048201527f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1690635f259aba90602401602060405180830381865afa1580156109b9573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906109dd9190611121565b610a13576040517f0129bb9900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610a1c81610cb4565b50565b60008060008060007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663feaf968c6040518163ffffffff1660e01b815260040160a060405180830381865afa158015610a92573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610ab69190611196565b939850919650945092509050610ace85858484610d52565b60007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663182df0f56040518163ffffffff1660e01b8152600401602060405180830381865afa158015610b3b573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610b5f91906111ee565b9050610b6a81610ded565b9050670de0b6b3a7640000610b7f8683611236565b610b89919061124d565b9450509091929394565b610b9b610e51565b600080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff001690557f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa335b60405173ffffffffffffffffffffffffffffffffffffffff909116815260200160405180910390a1565b610c18610ec2565b600080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff001660011790557f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258610be63390565b6000612710610c9a7f000000000000000000000000000000000000000000000000000000000000000082611288565b610ca49084611236565b610cae919061124d565b92915050565b801580610cd05750610cce81610cc983610c6b565b610f2f565b155b15610d07576040517f9aadd6f000000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60018190557f82e7ee47180a631312683eeb2a85ad264c9af490d54de5a75bbdb95b968c6de281610d3781610c6b565b6040805192835260208301919091520160405180910390a150565b60008313610d8c576040517f56e05d2b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8369ffffffffffffffffffff168169ffffffffffffffffffff161080610db0575081155b15610de7576040517fb1cf675500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b50505050565b60015460009080831015610e2d576040517f6477ba0800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6000610e3882610c6b565b9050808411610e475783610e49565b805b949350505050565b60005460ff166104a0576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601460248201527f5061757361626c653a206e6f742070617573656400000000000000000000000060448201526064015b60405180910390fd5b60005460ff16156104a0576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601060248201527f5061757361626c653a20706175736564000000000000000000000000000000006044820152606401610eb9565b6000807f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663182df0f56040518163ffffffff1660e01b8152600401602060405180830381865afa158015610f9d573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610fc191906111ee565b905083811080610fd057508281115b15610fdf576000915050610cae565b5060019392505050565b60208101600e8310611024577f4e487b7100000000000000000000000000000000000000000000000000000000600052602160045260246000fd5b91905290565b600060208083528351808285015260005b818110156110575785810183015185820160400152820161103b565b5060006040828601015260407fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f8301168501019250505092915050565b6000602082840312156110a857600080fd5b813573ffffffffffffffffffffffffffffffffffffffff811681146110cc57600080fd5b9392505050565b69ffffffffffffffffffff81168114610a1c57600080fd5b6000602082840312156110fd57600080fd5b81356110cc816110d3565b60006020828403121561111a57600080fd5b5035919050565b60006020828403121561113357600080fd5b815180151581146110cc57600080fd5b600181811c9082168061115757607f821691505b602082108103611190577f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fd5b50919050565b600080600080600060a086880312156111ae57600080fd5b85516111b9816110d3565b8095505060208601519350604086015192506060860151915060808601516111e0816110d3565b809150509295509295909350565b60006020828403121561120057600080fd5b5051919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b8082028115828204841417610cae57610cae611207565b600082611283577f4e487b7100000000000000000000000000000000000000000000000000000000600052601260045260246000fd5b500490565b80820180821115610cae57610cae61120756fea2646970667358221220a2d5628139b7b5bc076eae5b9c288f73f05c1cfd5d469b1a824a6cf649a74ec464736f6c63430008110033";

type CompoundPriceFeedConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: CompoundPriceFeedConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class CompoundPriceFeed__factory extends ContractFactory {
  constructor(...args: CompoundPriceFeedConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
    this.contractName = "CompoundPriceFeed";
  }

  override deploy(
    addressProvider: PromiseOrValue<string>,
    _cToken: PromiseOrValue<string>,
    _priceFeed: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<CompoundPriceFeed> {
    return super.deploy(
      addressProvider,
      _cToken,
      _priceFeed,
      overrides || {}
    ) as Promise<CompoundPriceFeed>;
  }
  override getDeployTransaction(
    addressProvider: PromiseOrValue<string>,
    _cToken: PromiseOrValue<string>,
    _priceFeed: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(
      addressProvider,
      _cToken,
      _priceFeed,
      overrides || {}
    );
  }
  override attach(address: string): CompoundPriceFeed {
    return super.attach(address) as CompoundPriceFeed;
  }
  override connect(signer: Signer): CompoundPriceFeed__factory {
    return super.connect(signer) as CompoundPriceFeed__factory;
  }
  static readonly contractName: "CompoundPriceFeed";

  public readonly contractName: "CompoundPriceFeed";

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): CompoundPriceFeedInterface {
    return new utils.Interface(_abi) as CompoundPriceFeedInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): CompoundPriceFeed {
    return new Contract(address, _abi, signerOrProvider) as CompoundPriceFeed;
  }
}