import {
  PoolV3CoreConfigurator,
  wethConfigMainnet,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(wethConfigMainnet);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
