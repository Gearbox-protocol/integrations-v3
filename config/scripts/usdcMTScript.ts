import { PoolV3CoreConfigurator } from "@gearbox-protocol/sdk-gov";

import { usdcMTConfig } from "../usdcMTconfig";

const poolCfg = PoolV3CoreConfigurator.new(usdcMTConfig);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
