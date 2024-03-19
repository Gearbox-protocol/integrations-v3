import {
  PoolV3CoreConfigurator,
  usdtConfigMainnet,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(usdtConfigMainnet);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
