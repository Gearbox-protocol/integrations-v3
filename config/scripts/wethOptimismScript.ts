import { PoolV3CoreConfigurator } from "@gearbox-protocol/sdk-gov";

import { config } from "../wethConfigOptimism";

const poolCfg = PoolV3CoreConfigurator.new(config);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
