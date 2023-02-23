import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";
import "solidity-coverage";

import { LOCAL_NETWORK, MAINNET_NETWORK } from "@gearbox-protocol/sdk";
import { config as dotEnvConfig } from "dotenv";
import { HardhatUserConfig } from "hardhat/types";

// gets data from .env file
dotEnvConfig();

const GOERLI_PRIVATE_KEY =
  process.env.GOERLI_PRIVATE_KEY! ||
  "0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3"; // well known private key

const GOERLI_PRIVATE_KEY2 =
  process.env.KOVAN2_PRIVATE_KEY! ||
  "0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3"; // well known private key

const BOXCODE_PRIVATE_KEY =
  process.env.BOXCODE_PRIVATE_KEY! ||
  "0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3"; // well known private key

const BVI_PRIVATE_KEY =
  process.env.BVI_PRIVATE_KEY! ||
  "0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3"; // well known private key

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.17",

        settings: {
          optimizer: {
            enabled: true,
            runs: 1000000,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: LOCAL_NETWORK,
      initialBaseFeePerGas: 0,
      allowUnlimitedContractSize: true,
    },
    localhost: {
      timeout: 0,
    },
    mainnet: {
      url: process.env.ETH_MAINNET_PROVIDER || "",
      accounts: [BOXCODE_PRIVATE_KEY, BVI_PRIVATE_KEY],
      chainId: MAINNET_NETWORK,
      timeout: 0,
      gasMultiplier: 1.15,
      minGasPrice: 1e9,
      allowUnlimitedContractSize: false,
    },

    goerli: {
      url: process.env.ETH_GOERLI_PROVIDER || "",
      accounts: [GOERLI_PRIVATE_KEY, GOERLI_PRIVATE_KEY2],
      gasMultiplier: 1.8,
      minGasPrice: 1e9,
      timeout: 0,
      allowUnlimitedContractSize: false,
    },
  },
  gasReporter: {
    enabled: false,
    currency: "USD",
    gasPrice: 21,
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
  },
  abiExporter: {
    path: "./abi",
    clear: true,
    flat: true,
    spacing: 2,
  },
  contractSizer: {
    alphaSort: false,
    disambiguatePaths: false,
    runOnCompile: true,
    except: ["Test", "Mock"],
  },
};

if (process.env.ETHERSCAN_API_KEY) {
  config.etherscan = {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY,
  };
}

export default config;
