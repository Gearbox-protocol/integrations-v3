import { PoolV3CoreConfigurator } from "@gearbox-protocol/sdk-gov";

import { wbtcTConfig } from "./data/wbtcTData";

const poolCfg = PoolV3CoreConfigurator.new(wbtcTConfig);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
