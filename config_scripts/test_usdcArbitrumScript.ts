import {
  PoolV3CoreConfigurator,
  testUsdcConfigArbitrum,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(testUsdcConfigArbitrum);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
