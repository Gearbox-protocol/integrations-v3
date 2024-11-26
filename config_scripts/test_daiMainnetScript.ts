import {
  PoolV3CoreConfigurator,
  testDaiConfigMainnet,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(testDaiConfigMainnet);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
