/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BytesLike,
  CallOverrides,
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

export interface IBalancerStablePoolInterface extends utils.Interface {
  functions: {
    "getActualSupply()": FunctionFragment;
    "getPoolId()": FunctionFragment;
    "getRate()": FunctionFragment;
    "totalSupply()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "getActualSupply"
      | "getPoolId"
      | "getRate"
      | "totalSupply"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "getActualSupply",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "getPoolId", values?: undefined): string;
  encodeFunctionData(functionFragment: "getRate", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "totalSupply",
    values?: undefined
  ): string;

  decodeFunctionResult(
    functionFragment: "getActualSupply",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "getPoolId", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "getRate", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "totalSupply",
    data: BytesLike
  ): Result;

  events: {};
}

export interface IBalancerStablePool extends BaseContract {
  contractName: "IBalancerStablePool";

  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IBalancerStablePoolInterface;

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
    getActualSupply(overrides?: CallOverrides): Promise<[BigNumber]>;

    getPoolId(overrides?: CallOverrides): Promise<[string]>;

    getRate(overrides?: CallOverrides): Promise<[BigNumber]>;

    totalSupply(overrides?: CallOverrides): Promise<[BigNumber]>;
  };

  getActualSupply(overrides?: CallOverrides): Promise<BigNumber>;

  getPoolId(overrides?: CallOverrides): Promise<string>;

  getRate(overrides?: CallOverrides): Promise<BigNumber>;

  totalSupply(overrides?: CallOverrides): Promise<BigNumber>;

  callStatic: {
    getActualSupply(overrides?: CallOverrides): Promise<BigNumber>;

    getPoolId(overrides?: CallOverrides): Promise<string>;

    getRate(overrides?: CallOverrides): Promise<BigNumber>;

    totalSupply(overrides?: CallOverrides): Promise<BigNumber>;
  };

  filters: {};

  estimateGas: {
    getActualSupply(overrides?: CallOverrides): Promise<BigNumber>;

    getPoolId(overrides?: CallOverrides): Promise<BigNumber>;

    getRate(overrides?: CallOverrides): Promise<BigNumber>;

    totalSupply(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    getActualSupply(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    getPoolId(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    getRate(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    totalSupply(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}