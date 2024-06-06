import {
  crvusdConfigMainnet,
  PoolV3CoreConfigurator,
} from "@gearbox-protocol/sdk-gov";

const poolCfg = PoolV3CoreConfigurator.new(crvusdConfigMainnet);
console.error(poolCfg.toString());

console.log(poolCfg.deployConfig());
