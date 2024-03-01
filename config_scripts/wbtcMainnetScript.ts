import {
  PoolV3CoreConfigurator,
  wbtcConfigMainnet,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(wbtcConfigMainnet);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
