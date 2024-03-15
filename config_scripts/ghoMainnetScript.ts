import {
  ghoConfigMainnet,
  PoolV3CoreConfigurator,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(ghoConfigMainnet);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
