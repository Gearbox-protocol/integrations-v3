import {
  PoolV3CoreConfigurator,
  wethConfigArbitrum,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(wethConfigArbitrum);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
