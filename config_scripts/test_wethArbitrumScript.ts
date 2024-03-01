import {
  PoolV3CoreConfigurator,
  testWethConfigArbitrum,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(testWethConfigArbitrum);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
