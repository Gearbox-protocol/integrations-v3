import {
  PoolV3CoreConfigurator,
  usdcConfigArbitrum,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(usdcConfigArbitrum);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
