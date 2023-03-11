/*
 * Copyright (c) 2022. Gearbox
 */
import { CMConfig, PoolConfig } from "../core/pool";
import { mainnetCreditManagers as mcm } from "./creditManagers";
import { mainnetPools as mp } from "./pools";

export const mainnetCreditManagers: Array<CMConfig> = mcm;
export const mainnetPools: Array<PoolConfig> = mp;
