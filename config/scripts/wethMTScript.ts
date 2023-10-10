import { PoolV3CoreConfigurator } from "@gearbox-protocol/sdk-gov";

import { wethMTData } from "../wethMTconfig";

const poolCfg = PoolV3CoreConfigurator.new(wethMTData);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
