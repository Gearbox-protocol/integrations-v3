import { PoolV3CoreConfigurator } from "@gearbox-protocol/sdk-gov";

import { usdcLevConfig } from "../usdcLevconfig";

const poolCfg = PoolV3CoreConfigurator.new(usdcLevConfig);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
