import {
  PoolV3CoreConfigurator,
  usdcConfigMainnet,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(usdcConfigMainnet);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
