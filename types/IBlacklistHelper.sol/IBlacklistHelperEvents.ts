/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type { BaseContract, BigNumber, Signer, utils } from "ethers";
import type { EventFragment } from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "../common";

export interface IBlacklistHelperEventsInterface extends utils.Interface {
  functions: {};

  events: {
    "ClaimableAdded(address,address,uint256)": EventFragment;
    "Claimed(address,address,address,uint256)": EventFragment;
    "CreditFacadeAdded(address)": EventFragment;
    "CreditFacadeRemoved(address)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "ClaimableAdded"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Claimed"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "CreditFacadeAdded"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "CreditFacadeRemoved"): EventFragment;
}

export interface ClaimableAddedEventObject {
  underlying: string;
  holder: string;
  amount: BigNumber;
}
export type ClaimableAddedEvent = TypedEvent<
  [string, string, BigNumber],
  ClaimableAddedEventObject
>;

export type ClaimableAddedEventFilter = TypedEventFilter<ClaimableAddedEvent>;

export interface ClaimedEventObject {
  underlying: string;
  holder: string;
  to: string;
  amount: BigNumber;
}
export type ClaimedEvent = TypedEvent<
  [string, string, string, BigNumber],
  ClaimedEventObject
>;

export type ClaimedEventFilter = TypedEventFilter<ClaimedEvent>;

export interface CreditFacadeAddedEventObject {
  creditFacade: string;
}
export type CreditFacadeAddedEvent = TypedEvent<
  [string],
  CreditFacadeAddedEventObject
>;

export type CreditFacadeAddedEventFilter =
  TypedEventFilter<CreditFacadeAddedEvent>;

export interface CreditFacadeRemovedEventObject {
  creditFacade: string;
}
export type CreditFacadeRemovedEvent = TypedEvent<
  [string],
  CreditFacadeRemovedEventObject
>;

export type CreditFacadeRemovedEventFilter =
  TypedEventFilter<CreditFacadeRemovedEvent>;

export interface IBlacklistHelperEvents extends BaseContract {
  contractName: "IBlacklistHelperEvents";

  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IBlacklistHelperEventsInterface;

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

  functions: {};

  callStatic: {};

  filters: {
    "ClaimableAdded(address,address,uint256)"(
      underlying?: PromiseOrValue<string> | null,
      holder?: PromiseOrValue<string> | null,
      amount?: null
    ): ClaimableAddedEventFilter;
    ClaimableAdded(
      underlying?: PromiseOrValue<string> | null,
      holder?: PromiseOrValue<string> | null,
      amount?: null
    ): ClaimableAddedEventFilter;

    "Claimed(address,address,address,uint256)"(
      underlying?: PromiseOrValue<string> | null,
      holder?: PromiseOrValue<string> | null,
      to?: null,
      amount?: null
    ): ClaimedEventFilter;
    Claimed(
      underlying?: PromiseOrValue<string> | null,
      holder?: PromiseOrValue<string> | null,
      to?: null,
      amount?: null
    ): ClaimedEventFilter;

    "CreditFacadeAdded(address)"(
      creditFacade?: PromiseOrValue<string> | null
    ): CreditFacadeAddedEventFilter;
    CreditFacadeAdded(
      creditFacade?: PromiseOrValue<string> | null
    ): CreditFacadeAddedEventFilter;

    "CreditFacadeRemoved(address)"(
      creditFacade?: PromiseOrValue<string> | null
    ): CreditFacadeRemovedEventFilter;
    CreditFacadeRemoved(
      creditFacade?: PromiseOrValue<string> | null
    ): CreditFacadeRemovedEventFilter;
  };

  estimateGas: {};

  populateTransaction: {};
}