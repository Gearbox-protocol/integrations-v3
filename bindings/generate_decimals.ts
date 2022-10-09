import {
  IERC20Metadata__factory,
  SupportedToken,
  supportedTokens,
  tokenDataByNetwork,
} from "@gearbox-protocol/sdk";
import * as fs from "fs";
import { ethers } from "hardhat";

async function generateTokens() {
  const accounts = await ethers.getSigners();
  const deployer = accounts[0];

  const tokenList: Array<string> = [];
  for (let token of Object.keys(supportedTokens)) {
    const address = tokenDataByNetwork.Mainnet[token as SupportedToken];
    const decimals = await IERC20Metadata__factory.connect(
      address,
      deployer,
    ).decimals();
    tokenList.push(`"${token}": ${decimals.toString()}`);
  }

  const file = `import { SupportedToken } from "./token";
  
  export const decimals: Record<SupportedToken, number> = {
    ${tokenList.join(",\n")}
   } `;

  fs.writeFileSync("./decimals.ts", file);
}

generateTokens()
  .then(() => {
    process.exit(0);
  })
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
