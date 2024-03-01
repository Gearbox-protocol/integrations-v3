import {
  PoolV3CoreConfigurator,
  testUsdcConfigMainnet,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(testUsdcConfigMainnet);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
