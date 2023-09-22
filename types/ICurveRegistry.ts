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

export interface ICurveRegistryInterface extends utils.Interface {
  functions: {
    "get_lp_token(address)": FunctionFragment;
    "get_n_coins(address)": FunctionFragment;
    "get_pool_from_lp_token(address)": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "get_lp_token"
      | "get_n_coins"
      | "get_pool_from_lp_token"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "get_lp_token",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "get_n_coins",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "get_pool_from_lp_token",
    values: [PromiseOrValue<string>]
  ): string;

  decodeFunctionResult(
    functionFragment: "get_lp_token",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "get_n_coins",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "get_pool_from_lp_token",
    data: BytesLike
  ): Result;

  events: {};
}

export interface ICurveRegistry extends BaseContract {
  contractName: "ICurveRegistry";

  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: ICurveRegistryInterface;

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
    get_lp_token(
      pool: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[string]>;

    get_n_coins(
      pool: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    get_pool_from_lp_token(
      token: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[string]>;
  };

  get_lp_token(
    pool: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<string>;

  get_n_coins(
    pool: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  get_pool_from_lp_token(
    token: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<string>;

  callStatic: {
    get_lp_token(
      pool: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<string>;

    get_n_coins(
      pool: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    get_pool_from_lp_token(
      token: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<string>;
  };

  filters: {};

  estimateGas: {
    get_lp_token(
      pool: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    get_n_coins(
      pool: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    get_pool_from_lp_token(
      token: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    get_lp_token(
      pool: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    get_n_coins(
      pool: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    get_pool_from_lp_token(
      token: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}