/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type { FunctionFragment, Result } from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "./common";

export type BatchSwapStepStruct = {
  poolId: PromiseOrValue<BytesLike>;
  assetInIndex: PromiseOrValue<BigNumberish>;
  assetOutIndex: PromiseOrValue<BigNumberish>;
  amount: PromiseOrValue<BigNumberish>;
  userData: PromiseOrValue<BytesLike>;
};

export type BatchSwapStepStructOutput = [
  string,
  BigNumber,
  BigNumber,
  BigNumber,
  string
] & {
  poolId: string;
  assetInIndex: BigNumber;
  assetOutIndex: BigNumber;
  amount: BigNumber;
  userData: string;
};

export type FundManagementStruct = {
  sender: PromiseOrValue<string>;
  fromInternalBalance: PromiseOrValue<boolean>;
  recipient: PromiseOrValue<string>;
  toInternalBalance: PromiseOrValue<boolean>;
};

export type FundManagementStructOutput = [string, boolean, string, boolean] & {
  sender: string;
  fromInternalBalance: boolean;
  recipient: string;
  toInternalBalance: boolean;
};

export type ExitPoolRequestStruct = {
  assets: PromiseOrValue<string>[];
  minAmountsOut: PromiseOrValue<BigNumberish>[];
  userData: PromiseOrValue<BytesLike>;
  toInternalBalance: PromiseOrValue<boolean>;
};

export type ExitPoolRequestStructOutput = [
  string[],
  BigNumber[],
  string,
  boolean
] & {
  assets: string[];
  minAmountsOut: BigNumber[];
  userData: string;
  toInternalBalance: boolean;
};

export type JoinPoolRequestStruct = {
  assets: PromiseOrValue<string>[];
  maxAmountsIn: PromiseOrValue<BigNumberish>[];
  userData: PromiseOrValue<BytesLike>;
  fromInternalBalance: PromiseOrValue<boolean>;
};

export type JoinPoolRequestStructOutput = [
  string[],
  BigNumber[],
  string,
  boolean
] & {
  assets: string[];
  maxAmountsIn: BigNumber[];
  userData: string;
  fromInternalBalance: boolean;
};

export type SingleSwapStruct = {
  poolId: PromiseOrValue<BytesLike>;
  kind: PromiseOrValue<BigNumberish>;
  assetIn: PromiseOrValue<string>;
  assetOut: PromiseOrValue<string>;
  amount: PromiseOrValue<BigNumberish>;
  userData: PromiseOrValue<BytesLike>;
};

export type SingleSwapStructOutput = [
  string,
  number,
  string,
  string,
  BigNumber,
  string
] & {
  poolId: string;
  kind: number;
  assetIn: string;
  assetOut: string;
  amount: BigNumber;
  userData: string;
};

export type SingleSwapAllStruct = {
  poolId: PromiseOrValue<BytesLike>;
  assetIn: PromiseOrValue<string>;
  assetOut: PromiseOrValue<string>;
  userData: PromiseOrValue<BytesLike>;
};

export type SingleSwapAllStructOutput = [string, string, string, string] & {
  poolId: string;
  assetIn: string;
  assetOut: string;
  userData: string;
};

export interface BalancerV2VaultAdapterInterface extends utils.Interface {
  functions: {
    "_acl()": FunctionFragment;
    "_gearboxAdapterType()": FunctionFragment;
    "_gearboxAdapterVersion()": FunctionFragment;
    "addressProvider()": FunctionFragment;
    "batchSwap(uint8,(bytes32,uint256,uint256,uint256,bytes)[],address[],(address,bool,address,bool),int256[],uint256)": FunctionFragment;
    "creditManager()": FunctionFragment;
    "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))": FunctionFragment;
    "exitPoolSingleAsset(bytes32,address,uint256,uint256)": FunctionFragment;
    "exitPoolSingleAssetAll(bytes32,address,uint256)": FunctionFragment;
    "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))": FunctionFragment;
    "joinPoolSingleAsset(bytes32,address,uint256,uint256)": FunctionFragment;
    "joinPoolSingleAssetAll(bytes32,address,uint256)": FunctionFragment;
    "poolIdStatus(bytes32)": FunctionFragment;
    "setPoolIDStatus(bytes32,uint8)": FunctionFragment;
    "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)": FunctionFragment;
    "swapAll((bytes32,address,address,bytes),uint256,uint256)": FunctionFragment;
    "targetContract()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "_acl"
      | "_gearboxAdapterType"
      | "_gearboxAdapterVersion"
      | "addressProvider"
      | "batchSwap"
      | "creditManager"
      | "exitPool"
      | "exitPoolSingleAsset"
      | "exitPoolSingleAssetAll"
      | "joinPool"
      | "joinPoolSingleAsset"
      | "joinPoolSingleAssetAll"
      | "poolIdStatus"
      | "setPoolIDStatus"
      | "swap"
      | "swapAll"
      | "targetContract"
  ): FunctionFragment;

  encodeFunctionData(functionFragment: "_acl", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "_gearboxAdapterType",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "_gearboxAdapterVersion",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "addressProvider",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "batchSwap",
    values: [
      PromiseOrValue<BigNumberish>,
      BatchSwapStepStruct[],
      PromiseOrValue<string>[],
      FundManagementStruct,
      PromiseOrValue<BigNumberish>[],
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "creditManager",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "exitPool",
    values: [
      PromiseOrValue<BytesLike>,
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      ExitPoolRequestStruct
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "exitPoolSingleAsset",
    values: [
      PromiseOrValue<BytesLike>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "exitPoolSingleAssetAll",
    values: [
      PromiseOrValue<BytesLike>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "joinPool",
    values: [
      PromiseOrValue<BytesLike>,
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      JoinPoolRequestStruct
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "joinPoolSingleAsset",
    values: [
      PromiseOrValue<BytesLike>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "joinPoolSingleAssetAll",
    values: [
      PromiseOrValue<BytesLike>,
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "poolIdStatus",
    values: [PromiseOrValue<BytesLike>]
  ): string;
  encodeFunctionData(
    functionFragment: "setPoolIDStatus",
    values: [PromiseOrValue<BytesLike>, PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "swap",
    values: [
      SingleSwapStruct,
      FundManagementStruct,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "swapAll",
    values: [
      SingleSwapAllStruct,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "targetContract",
    values?: undefined
  ): string;

  decodeFunctionResult(functionFragment: "_acl", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "_gearboxAdapterType",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "_gearboxAdapterVersion",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "addressProvider",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "batchSwap", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "creditManager",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "exitPool", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "exitPoolSingleAsset",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "exitPoolSingleAssetAll",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "joinPool", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "joinPoolSingleAsset",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "joinPoolSingleAssetAll",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "poolIdStatus",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setPoolIDStatus",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "swap", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "swapAll", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "targetContract",
    data: BytesLike
  ): Result;

  events: {};
}

export interface BalancerV2VaultAdapter extends BaseContract {
  contractName: "BalancerV2VaultAdapter";

  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: BalancerV2VaultAdapterInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    _acl(overrides?: CallOverrides): Promise<[string]>;

    _gearboxAdapterType(overrides?: CallOverrides): Promise<[number]>;

    _gearboxAdapterVersion(overrides?: CallOverrides): Promise<[number]>;

    addressProvider(overrides?: CallOverrides): Promise<[string]>;

    batchSwap(
      kind: PromiseOrValue<BigNumberish>,
      swaps: BatchSwapStepStruct[],
      assets: PromiseOrValue<string>[],
      arg3: FundManagementStruct,
      limits: PromiseOrValue<BigNumberish>[],
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    creditManager(overrides?: CallOverrides): Promise<[string]>;

    exitPool(
      poolId: PromiseOrValue<BytesLike>,
      arg1: PromiseOrValue<string>,
      arg2: PromiseOrValue<string>,
      request: ExitPoolRequestStruct,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    exitPoolSingleAsset(
      poolId: PromiseOrValue<BytesLike>,
      assetOut: PromiseOrValue<string>,
      amountIn: PromiseOrValue<BigNumberish>,
      minAmountOut: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    exitPoolSingleAssetAll(
      poolId: PromiseOrValue<BytesLike>,
      assetOut: PromiseOrValue<string>,
      minRateRAY: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    joinPool(
      poolId: PromiseOrValue<BytesLike>,
      arg1: PromiseOrValue<string>,
      arg2: PromiseOrValue<string>,
      request: JoinPoolRequestStruct,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    joinPoolSingleAsset(
      poolId: PromiseOrValue<BytesLike>,
      assetIn: PromiseOrValue<string>,
      amountIn: PromiseOrValue<BigNumberish>,
      minAmountOut: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    joinPoolSingleAssetAll(
      poolId: PromiseOrValue<BytesLike>,
      assetIn: PromiseOrValue<string>,
      minRateRAY: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    poolIdStatus(
      arg0: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<[number]>;

    setPoolIDStatus(
      poolId: PromiseOrValue<BytesLike>,
      newStatus: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    swap(
      singleSwap: SingleSwapStruct,
      arg1: FundManagementStruct,
      limit: PromiseOrValue<BigNumberish>,
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    swapAll(
      singleSwapAll: SingleSwapAllStruct,
      limitRateRAY: PromiseOrValue<BigNumberish>,
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    targetContract(overrides?: CallOverrides): Promise<[string]>;
  };

  _acl(overrides?: CallOverrides): Promise<string>;

  _gearboxAdapterType(overrides?: CallOverrides): Promise<number>;

  _gearboxAdapterVersion(overrides?: CallOverrides): Promise<number>;

  addressProvider(overrides?: CallOverrides): Promise<string>;

  batchSwap(
    kind: PromiseOrValue<BigNumberish>,
    swaps: BatchSwapStepStruct[],
    assets: PromiseOrValue<string>[],
    arg3: FundManagementStruct,
    limits: PromiseOrValue<BigNumberish>[],
    deadline: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  creditManager(overrides?: CallOverrides): Promise<string>;

  exitPool(
    poolId: PromiseOrValue<BytesLike>,
    arg1: PromiseOrValue<string>,
    arg2: PromiseOrValue<string>,
    request: ExitPoolRequestStruct,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  exitPoolSingleAsset(
    poolId: PromiseOrValue<BytesLike>,
    assetOut: PromiseOrValue<string>,
    amountIn: PromiseOrValue<BigNumberish>,
    minAmountOut: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  exitPoolSingleAssetAll(
    poolId: PromiseOrValue<BytesLike>,
    assetOut: PromiseOrValue<string>,
    minRateRAY: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  joinPool(
    poolId: PromiseOrValue<BytesLike>,
    arg1: PromiseOrValue<string>,
    arg2: PromiseOrValue<string>,
    request: JoinPoolRequestStruct,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  joinPoolSingleAsset(
    poolId: PromiseOrValue<BytesLike>,
    assetIn: PromiseOrValue<string>,
    amountIn: PromiseOrValue<BigNumberish>,
    minAmountOut: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  joinPoolSingleAssetAll(
    poolId: PromiseOrValue<BytesLike>,
    assetIn: PromiseOrValue<string>,
    minRateRAY: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  poolIdStatus(
    arg0: PromiseOrValue<BytesLike>,
    overrides?: CallOverrides
  ): Promise<number>;

  setPoolIDStatus(
    poolId: PromiseOrValue<BytesLike>,
    newStatus: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  swap(
    singleSwap: SingleSwapStruct,
    arg1: FundManagementStruct,
    limit: PromiseOrValue<BigNumberish>,
    deadline: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  swapAll(
    singleSwapAll: SingleSwapAllStruct,
    limitRateRAY: PromiseOrValue<BigNumberish>,
    deadline: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  targetContract(overrides?: CallOverrides): Promise<string>;

  callStatic: {
    _acl(overrides?: CallOverrides): Promise<string>;

    _gearboxAdapterType(overrides?: CallOverrides): Promise<number>;

    _gearboxAdapterVersion(overrides?: CallOverrides): Promise<number>;

    addressProvider(overrides?: CallOverrides): Promise<string>;

    batchSwap(
      kind: PromiseOrValue<BigNumberish>,
      swaps: BatchSwapStepStruct[],
      assets: PromiseOrValue<string>[],
      arg3: FundManagementStruct,
      limits: PromiseOrValue<BigNumberish>[],
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    creditManager(overrides?: CallOverrides): Promise<string>;

    exitPool(
      poolId: PromiseOrValue<BytesLike>,
      arg1: PromiseOrValue<string>,
      arg2: PromiseOrValue<string>,
      request: ExitPoolRequestStruct,
      overrides?: CallOverrides
    ): Promise<void>;

    exitPoolSingleAsset(
      poolId: PromiseOrValue<BytesLike>,
      assetOut: PromiseOrValue<string>,
      amountIn: PromiseOrValue<BigNumberish>,
      minAmountOut: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    exitPoolSingleAssetAll(
      poolId: PromiseOrValue<BytesLike>,
      assetOut: PromiseOrValue<string>,
      minRateRAY: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    joinPool(
      poolId: PromiseOrValue<BytesLike>,
      arg1: PromiseOrValue<string>,
      arg2: PromiseOrValue<string>,
      request: JoinPoolRequestStruct,
      overrides?: CallOverrides
    ): Promise<void>;

    joinPoolSingleAsset(
      poolId: PromiseOrValue<BytesLike>,
      assetIn: PromiseOrValue<string>,
      amountIn: PromiseOrValue<BigNumberish>,
      minAmountOut: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    joinPoolSingleAssetAll(
      poolId: PromiseOrValue<BytesLike>,
      assetIn: PromiseOrValue<string>,
      minRateRAY: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    poolIdStatus(
      arg0: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<number>;

    setPoolIDStatus(
      poolId: PromiseOrValue<BytesLike>,
      newStatus: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    swap(
      singleSwap: SingleSwapStruct,
      arg1: FundManagementStruct,
      limit: PromiseOrValue<BigNumberish>,
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    swapAll(
      singleSwapAll: SingleSwapAllStruct,
      limitRateRAY: PromiseOrValue<BigNumberish>,
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<void>;

    targetContract(overrides?: CallOverrides): Promise<string>;
  };

  filters: {};

  estimateGas: {
    _acl(overrides?: CallOverrides): Promise<BigNumber>;

    _gearboxAdapterType(overrides?: CallOverrides): Promise<BigNumber>;

    _gearboxAdapterVersion(overrides?: CallOverrides): Promise<BigNumber>;

    addressProvider(overrides?: CallOverrides): Promise<BigNumber>;

    batchSwap(
      kind: PromiseOrValue<BigNumberish>,
      swaps: BatchSwapStepStruct[],
      assets: PromiseOrValue<string>[],
      arg3: FundManagementStruct,
      limits: PromiseOrValue<BigNumberish>[],
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    creditManager(overrides?: CallOverrides): Promise<BigNumber>;

    exitPool(
      poolId: PromiseOrValue<BytesLike>,
      arg1: PromiseOrValue<string>,
      arg2: PromiseOrValue<string>,
      request: ExitPoolRequestStruct,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    exitPoolSingleAsset(
      poolId: PromiseOrValue<BytesLike>,
      assetOut: PromiseOrValue<string>,
      amountIn: PromiseOrValue<BigNumberish>,
      minAmountOut: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    exitPoolSingleAssetAll(
      poolId: PromiseOrValue<BytesLike>,
      assetOut: PromiseOrValue<string>,
      minRateRAY: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    joinPool(
      poolId: PromiseOrValue<BytesLike>,
      arg1: PromiseOrValue<string>,
      arg2: PromiseOrValue<string>,
      request: JoinPoolRequestStruct,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    joinPoolSingleAsset(
      poolId: PromiseOrValue<BytesLike>,
      assetIn: PromiseOrValue<string>,
      amountIn: PromiseOrValue<BigNumberish>,
      minAmountOut: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    joinPoolSingleAssetAll(
      poolId: PromiseOrValue<BytesLike>,
      assetIn: PromiseOrValue<string>,
      minRateRAY: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    poolIdStatus(
      arg0: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    setPoolIDStatus(
      poolId: PromiseOrValue<BytesLike>,
      newStatus: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    swap(
      singleSwap: SingleSwapStruct,
      arg1: FundManagementStruct,
      limit: PromiseOrValue<BigNumberish>,
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    swapAll(
      singleSwapAll: SingleSwapAllStruct,
      limitRateRAY: PromiseOrValue<BigNumberish>,
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    targetContract(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    _acl(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    _gearboxAdapterType(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    _gearboxAdapterVersion(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    addressProvider(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    batchSwap(
      kind: PromiseOrValue<BigNumberish>,
      swaps: BatchSwapStepStruct[],
      assets: PromiseOrValue<string>[],
      arg3: FundManagementStruct,
      limits: PromiseOrValue<BigNumberish>[],
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    creditManager(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    exitPool(
      poolId: PromiseOrValue<BytesLike>,
      arg1: PromiseOrValue<string>,
      arg2: PromiseOrValue<string>,
      request: ExitPoolRequestStruct,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    exitPoolSingleAsset(
      poolId: PromiseOrValue<BytesLike>,
      assetOut: PromiseOrValue<string>,
      amountIn: PromiseOrValue<BigNumberish>,
      minAmountOut: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    exitPoolSingleAssetAll(
      poolId: PromiseOrValue<BytesLike>,
      assetOut: PromiseOrValue<string>,
      minRateRAY: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    joinPool(
      poolId: PromiseOrValue<BytesLike>,
      arg1: PromiseOrValue<string>,
      arg2: PromiseOrValue<string>,
      request: JoinPoolRequestStruct,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    joinPoolSingleAsset(
      poolId: PromiseOrValue<BytesLike>,
      assetIn: PromiseOrValue<string>,
      amountIn: PromiseOrValue<BigNumberish>,
      minAmountOut: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    joinPoolSingleAssetAll(
      poolId: PromiseOrValue<BytesLike>,
      assetIn: PromiseOrValue<string>,
      minRateRAY: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    poolIdStatus(
      arg0: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    setPoolIDStatus(
      poolId: PromiseOrValue<BytesLike>,
      newStatus: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    swap(
      singleSwap: SingleSwapStruct,
      arg1: FundManagementStruct,
      limit: PromiseOrValue<BigNumberish>,
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    swapAll(
      singleSwapAll: SingleSwapAllStruct,
      limitRateRAY: PromiseOrValue<BigNumberish>,
      deadline: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    targetContract(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}