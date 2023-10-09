import { PoolV3CoreConfigurator } from "@gearbox-protocol/sdk-gov";

import { usdcLevConfig } from "./data/usdcLevData";

const poolCfg = PoolV3CoreConfigurator.new(usdcLevConfig);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
