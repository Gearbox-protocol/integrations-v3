import { PoolV3CoreConfigurator } from "@gearbox-protocol/sdk-gov";

import { usdcMTConfig } from "./data/usdcMTData";

const poolCfg = PoolV3CoreConfigurator.new(usdcMTConfig);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
