import {
  AdapterInterface,
  contractParams,
  contractsByNetwork,
  CurveLPTokenData,
  LPTokens,
  lpTokens,
  OracleType,
  priceFeedsByNetwork,
  SupportedContract,
  SupportedToken,
  supportedTokens,
  tokenDataByNetwork,
  TokenType,
} from "@gearbox-protocol/sdk";
import * as fs from "fs";

import { mainnetCreditManagers } from "../config/liveTests";

function safeEnum(t: string): string {
  if (!isNaN(parseInt(t.charAt(0), 10))) {
    return `_${t}`;
  }
  return t;
}

const tokens: Array<SupportedToken> = Object.keys(supportedTokens).filter(
  t => tokenDataByNetwork.Mainnet[t as SupportedToken] !== "",
) as Array<SupportedToken>;

/// ---------------- Tokens.sol -----------------------------

const tokensEnum = tokens.map(t => safeEnum(t)).join(",\n");
let file = fs.readFileSync("./bindings/Tokens.sol").toString();
file = file.replace("// $TOKENS$", `,\n${tokensEnum}`);
fs.writeFileSync("./contracts/test/config/Tokens.sol", file);

/// ---------------- TokensDataLive.sol ---------------------

let tokenAddresses = `td = new TokenData[](${tokens.length});`;

tokenAddresses += tokens
  .map(
    (t, num) =>
      `td[${num}] = TokenData({ id: Tokens.${safeEnum(t)}, addr: ${
        tokenDataByNetwork.Mainnet[t]
      }, symbol: "${t}", tokenType: TokenType.${
        TokenType[supportedTokens[t].type]
      } });`,
  )

  .join("\n");

let tokenAddressesGoerli = `td = new TokenData[](${tokens.length});`;

tokenAddressesGoerli += tokens
  .map(
    (t, num) =>
      `td[${num}] = TokenData({ id: Tokens.${safeEnum(t)}, addr: ${
        tokenDataByNetwork.Goerli[t]
      }, symbol: "${t}", tokenType: TokenType.${
        TokenType[supportedTokens[t].type]
      } });`,
  )

  .join("\n");

file = fs.readFileSync("./bindings/TokensDataLive.sol").toString();
file = file.replace("// $TOKEN_ADDRESSES$", tokenAddresses);
file = file.replace("// $GOERLI_TOKEN_ADDRESSES$", tokenAddressesGoerli);
fs.writeFileSync("./contracts/test/config/TokensDataLive.sol", file);

/// ---------------- PriceFeedDataLive.sol -----------------------------

const chainlinkPriceFeeds = Object.entries(priceFeedsByNetwork)
  .filter(
    ([, oracleData]) =>
      oracleData.priceFeedUSD?.type === OracleType.CHAINLINK_ORACLE,
  )
  .map(([token, oracleData]) => {
    if (oracleData.priceFeedUSD?.type === OracleType.CHAINLINK_ORACLE) {
      const address: string | undefined =
        oracleData.priceFeedUSD!.address.Mainnet;

      return address
        ? `chainlinkPriceFeeds.push(ChainlinkPriceFeedData({
    token: Tokens.${safeEnum(token as SupportedToken)},
    priceFeed: ${oracleData.priceFeedUSD!.address.Mainnet}
  }));`
        : "";
    }

    return "";
  })
  .filter(t => t !== "")
  .join("\n");

const chainlinkPriceFeedsGoerli = Object.entries(priceFeedsByNetwork)
  .filter(
    ([, oracleData]) =>
      oracleData.priceFeedUSD?.type === OracleType.CHAINLINK_ORACLE,
  )
  .map(([token, oracleData]) => {
    if (oracleData.priceFeedUSD?.type === OracleType.CHAINLINK_ORACLE) {
      const address: string | undefined =
        oracleData.priceFeedUSD!.address.Goerli;

      return address
        ? `chainlinkPriceFeeds.push(ChainlinkPriceFeedData({
  token: Tokens.${safeEnum(token as SupportedToken)},
  priceFeed: ${oracleData.priceFeedUSD!.address.Goerli}
}));`
        : "";
    }

    return "";
  })
  .filter(t => t !== "")
  .join("\n");

const zeroPriceFeeds = Object.entries(priceFeedsByNetwork)
  .filter(
    ([, oracleData]) =>
      oracleData.priceFeedUSD?.type === OracleType.ZERO_ORACLE,
  )
  .map(
    ([token]) =>
      `zeroPriceFeeds.push(SingeTokenPriceFeedData({ token: Tokens.${safeEnum(
        token as SupportedToken,
      )} }));`,
  )
  .join("\n");

const curvePriceFeeds = Object.entries(priceFeedsByNetwork)
  .filter(
    ([, oracleData]) =>
      oracleData.priceFeedUSD?.type === OracleType.CURVE_LP_TOKEN_ORACLE,
  )
  .map(([token, oracleData]) => {
    if (oracleData.priceFeedUSD?.type === OracleType.CURVE_LP_TOKEN_ORACLE) {
      const assets = oracleData.priceFeedUSD.assets
        .map(a => `Tokens.${safeEnum(a)}`)
        .join(", ");

      return `curvePriceFeeds.push(CurvePriceFeedData({
          lpToken: Tokens.${safeEnum(token as SupportedToken)},
          assets: assets(${assets}),
          pool: Contracts.${
            (lpTokens[token as LPTokens] as CurveLPTokenData).pool
          }
        }));`;
    }
    return "";
  })
  .filter(t => t !== "")
  .join("\n");

const curveLikePriceFeeds = Object.entries(priceFeedsByNetwork)
  .filter(
    ([token, oracleData]) =>
      oracleData.priceFeedUSD?.type === OracleType.LIKE_CURVE_LP_TOKEN_ORACLE &&
      tokenDataByNetwork.Mainnet[token as SupportedToken] !== "",
  )
  .map(([token, oracleData]) => {
    if (
      oracleData.priceFeedUSD?.type === OracleType.LIKE_CURVE_LP_TOKEN_ORACLE
    ) {
      const symbol = oracleData.priceFeedUSD.curveSymbol;
      if (tokenDataByNetwork.Mainnet[token as SupportedToken] !== "") {
        return `likeCurvePriceFeeds.push(CurveLikePriceFeedData({
        lpToken: Tokens.${safeEnum(token as SupportedToken)},
        curveToken: Tokens.${safeEnum(symbol as SupportedToken)}
      }));`;
      }
    }
    return "";
  })
  .filter(t => t !== "")
  .join("\n");

const curveLikePriceFeedsGoerli = Object.entries(priceFeedsByNetwork)
  .filter(
    ([token, oracleData]) =>
      oracleData.priceFeedUSD?.type === OracleType.LIKE_CURVE_LP_TOKEN_ORACLE &&
      tokenDataByNetwork.Goerli[token as SupportedToken] !== "",
  )
  .map(([token, oracleData]) => {
    if (
      oracleData.priceFeedUSD?.type === OracleType.LIKE_CURVE_LP_TOKEN_ORACLE
    ) {
      const symbol = oracleData.priceFeedUSD.curveSymbol;
      if (tokenDataByNetwork.Goerli[token as SupportedToken] !== "") {
        return `likeCurvePriceFeeds.push(CurveLikePriceFeedData({
        lpToken: Tokens.${safeEnum(token as SupportedToken)},
        curveToken: Tokens.${safeEnum(symbol as SupportedToken)}
      }));`;
      }
    }
    return "";
  })
  .filter(t => t !== "")
  .join("\n");

const yearnPriceFeeds = Object.entries(priceFeedsByNetwork)
  .filter(
    ([, oracleData]) =>
      oracleData.priceFeedUSD?.type === OracleType.YEARN_TOKEN_ORACLE ||
      oracleData.priceFeedUSD?.type === OracleType.YEARN_CURVE_LP_TOKEN_ORACLE,
  )
  .map(
    ([token]) =>
      `yearnPriceFeeds.push(SingeTokenPriceFeedData({ token: Tokens.${safeEnum(
        token as SupportedToken,
      )} }));`,
  )
  .join("\n");

const wstethPriceFeed = Object.entries(priceFeedsByNetwork)
  .filter(
    ([, oracleData]) =>
      oracleData.priceFeedUSD?.type === OracleType.WSTETH_ORACLE,
  )
  .map(
    ([token]) =>
      `wstethPriceFeed = SingeTokenPriceFeedData({ token: Tokens.${safeEnum(
        token as SupportedToken,
      )} });`,
  )
  .join("\n");

file = fs.readFileSync("./bindings/PriceFeedDataLive.sol").toString();

file = file.replace("// $CHAINLINK_PRICE_FEEDS", chainlinkPriceFeeds);
file = file.replace(
  "// $GOERLI_CHAINLINK_PRICE_FEEDS",
  chainlinkPriceFeedsGoerli,
);
file = file.replace("// $ZERO_PRICE_FEEDS", zeroPriceFeeds);
file = file.replace("// $CURVE_PRICE_FEEDS", curvePriceFeeds);
file = file.replace("// $CURVE_LIKE_PRICE_FEEDS", curveLikePriceFeeds);
file = file.replace(
  "// $GOERLI_CURVE_LIKE_PRICE_FEEDS",
  curveLikePriceFeedsGoerli,
);
file = file.replace("// $YEARN_PRICE_FEEDS", yearnPriceFeeds);
file = file.replace("// $WSTETH_PRICE_FEED", wstethPriceFeed);

fs.writeFileSync("./contracts/test/config/PriceFeedDataLive.sol", file);

/// ---------------- SupportedContracts.sol -----------------------------

const contracts: Array<SupportedContract> = Object.keys(
  contractsByNetwork.Mainnet,
) as Array<SupportedContract>;

const contractsEnum = contracts.join(",\n");

let contractAddresses = `cd = new  ContractData[](${contracts.length});`;
contractAddresses += contracts
  .map(
    (t, num) =>
      `cd[${num}] = ContractData({ id: Contracts.${t}, addr:  ${contractsByNetwork.Mainnet[t]}, name: "${t}" });`,
  )
  .join("\n");

let contractAddressesGoerli = `cd = new  ContractData[](${contracts.length});`;
contractAddressesGoerli += contracts
  .map(
    (t, num) =>
      `cd[${num}] = ContractData({ id: Contracts.${t}, addr:  ${contractsByNetwork.Goerli[t]}, name: "${t}" });`,
  )
  .join("\n");

file = fs.readFileSync("./bindings/SupportedContracts.sol").toString();

file = file.replace("// $CONTRACTS_ENUM$", `, ${contractsEnum}`);
file = file.replace("// $CONTRACTS_ADDRESSES$", contractAddresses);
file = file.replace("// $GOERLI_CONTRACTS_ADDRESSES$", contractAddressesGoerli);

fs.writeFileSync("./contracts/test/config/SupportedContracts.sol", file);

/// ---------------- CreditConfigLive.sol -----------------------------
let config = "";

for (let c of mainnetCreditManagers) {
  config += `cm = creditManagerHumanOpts[Tokens.${safeEnum(c.symbol)}];`;
  config += `cm.minBorrowedAmount = ${c.minAmount.toString()};`;
  config += `cm.maxBorrowedAmount = ${c.maxAmount.toString()};`;
  config += `cm.degenNFT = address(0);`;
  config += `cm.expirable = false;`;

  config += c.collateralTokens
    .map(
      ct => `cm.collateralTokens.push(CollateralTokenHuman({
    token: Tokens.${safeEnum(ct.symbol)},
    liquidationThreshold: ${
      ct.liquidationThreshold === 0
        ? 1
        : Math.floor(ct.liquidationThreshold * 100)
    }
  }));`,
    )
    .join("\n");

  config += c.adapters
    .map(contract => `cm.contracts.push(Contracts.${contract});`)
    .join("\n");
}
file = fs.readFileSync("./bindings/CreditConfigLive.sol").toString();

file = file.replace("// $CREDIT_MANAGER_CONFIG", config);

fs.writeFileSync("./contracts/test/config/CreditConfigLive.sol", file);

/// ---------------- AdapterData.sol -----------------------------
let adapters = Object.entries(contractParams)
  .filter(
    ([, contractParam]) =>
      contractParam.type === AdapterInterface.UNISWAP_V2_ROUTER ||
      contractParam.type === AdapterInterface.UNISWAP_V3_ROUTER ||
      contractParam.type === AdapterInterface.YEARN_V2 ||
      contractParam.type === AdapterInterface.CONVEX_V1_BOOSTER ||
      contractParam.type === AdapterInterface.CONVEX_V1_CLAIM_ZAP ||
      contractParam.type === AdapterInterface.LIDO_V1 ||
      contractParam.type === AdapterInterface.UNIVERSAL ||
      contractParam.type === AdapterInterface.LIDO_WSTETH_V1,
  )
  .map(
    ([contract, contractParam]) =>
      `simpleAdapters.push(SimpleAdapter({targetContract:  Contracts.${contract},
        adapterType: AdapterType.${AdapterInterface[contractParam.type]}}));`,
  )
  .join("\n");

adapters += Object.entries(contractParams)
  .filter(
    ([, contractParam]) =>
      contractParam.type === AdapterInterface.CURVE_V1_2ASSETS ||
      contractParam.type === AdapterInterface.CURVE_V1_3ASSETS ||
      contractParam.type === AdapterInterface.CURVE_V1_4ASSETS,
  )
  .map(([contract, contractParam]) => {
    if (
      contractParam.type === AdapterInterface.CURVE_V1_2ASSETS ||
      contractParam.type === AdapterInterface.CURVE_V1_3ASSETS ||
      contractParam.type === AdapterInterface.CURVE_V1_4ASSETS
    ) {
      const basePool: SupportedContract | "NO_CONTRACT" =
        contractParam.tokens.includes("3Crv")
          ? "CURVE_3CRV_POOL"
          : "NO_CONTRACT";
      return `curveAdapters.push(CurveAdapter({targetContract:  Contracts.${contract},
  adapterType: AdapterType.${
    AdapterInterface[contractParam.type]
  }, lpToken: Tokens.${safeEnum(
        contractParam.lpToken,
      )}, basePool: Contracts.${basePool}}));`;
    }

    return "";
  })
  .join("\n");

adapters += Object.entries(contractParams)
  .filter(
    ([, contractParam]) =>
      contractParam.type === AdapterInterface.CURVE_V1_STECRV_POOL,
  )
  .map(([contract, contractParam]) => {
    if (contractParam.type === AdapterInterface.CURVE_V1_STECRV_POOL) {
      return `curveStEthAdapter = CurveStETHAdapter({curveETHGateway:  Contracts.${contract},
        adapterType: AdapterType.${
          AdapterInterface[contractParam.type]
        }, lpToken: Tokens.${safeEnum(contractParam.lpToken)}});`;
    }
    return "";
  })
  .join("\n");

adapters += Object.entries(contractParams)
  .filter(
    ([, contractParam]) =>
      contractParam.type === AdapterInterface.CURVE_V1_WRAPPER,
  )
  .map(([contract, contractParam]) => {
    if (contractParam.type === AdapterInterface.CURVE_V1_WRAPPER) {
      return `curveWrappers.push(CurveWrapper({targetContract:  Contracts.${contract},
  adapterType: AdapterType.${
    AdapterInterface[contractParam.type]
  }, lpToken: Tokens.${safeEnum(contractParam.lpToken)}, nCoins: ${
        contractParam.tokens.length
      }}));`;
    }
    return "";
  })
  .join("\n");

adapters += Object.entries(contractParams)
  .filter(
    ([, contractParam]) =>
      contractParam.type === AdapterInterface.CONVEX_V1_BASE_REWARD_POOL &&
      tokens.includes(contractParam.stakedToken),
  )
  .map(([contract, contractParam]) => {
    if (contractParam.type === AdapterInterface.CONVEX_V1_BASE_REWARD_POOL) {
      return `convexBasePoolAdapters.push(ConvexBasePoolAdapter({targetContract:  Contracts.${contract},
  adapterType: AdapterType.${
    AdapterInterface[contractParam.type]
  }, stakedToken: Tokens.${safeEnum(contractParam.stakedToken)}}));`;
    }
    return "";
  })
  .join("\n");

file = fs.readFileSync("./bindings/AdapterData.sol").toString();

file = file.replace("// $ADAPTERS_LIST", adapters);

fs.writeFileSync("./contracts/test/config/AdapterData.sol", file);
