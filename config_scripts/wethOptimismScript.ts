import {
  PoolV3CoreConfigurator,
  wethConfigOptimism,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(wethConfigOptimism);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
