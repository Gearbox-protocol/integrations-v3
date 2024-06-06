import {
  PoolV3CoreConfigurator,
  usdceConfigArbitrum,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(usdceConfigArbitrum);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
