import {
  daiConfigMainnet,
  PoolV3CoreConfigurator,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(daiConfigMainnet);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
