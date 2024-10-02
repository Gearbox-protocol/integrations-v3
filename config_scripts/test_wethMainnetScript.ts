import {
  PoolV3CoreConfigurator,
  testWethConfigMainnet,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(testWethConfigMainnet);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
