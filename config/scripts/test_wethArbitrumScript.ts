import { PoolV3CoreConfigurator } from "@gearbox-protocol/sdk-gov";

import { config } from "../test_wethConfigArbitrum";

const poolCfg = PoolV3CoreConfigurator.new(config);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
