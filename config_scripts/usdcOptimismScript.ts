import {
  PoolV3CoreConfigurator,
  usdcConfigOptimism,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(usdcConfigOptimism);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
