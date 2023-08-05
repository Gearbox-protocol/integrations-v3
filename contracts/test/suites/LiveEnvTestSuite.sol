// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

// import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";
// import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";
// import {PriceFeedDeployer} from "@gearbox-protocol/oracles-v3/contracts/test/suites/PriceFeedDeployer.sol";

// import {AddressProvider} from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";

// import {ACL} from "@gearbox-protocol/core-v2/contracts/core/ACL.sol";
// import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";
// import {IPriceOracleV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";

// import {PriceOracleV3} from "@gearbox-protocol/core-v3/contracts/core/PriceOracleV3.sol";
// import {IPoolService} from "@gearbox-protocol/core-v2/contracts/interfaces/IPoolService.sol";
// import {PoolV3} from "@gearbox-protocol/core-v3/contracts/pool/PoolV3.sol";
// import {GearStakingV3} from "@gearbox-protocol/core-v3/contracts/governance/GearStakingV3.sol";

// import {BotListV3} from "@gearbox-protocol/core-v3/contracts/core/BotListV3.sol";
// import {IPoolQuotaKeeperV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPoolQuotaKeeperV3.sol";
// import {IGaugeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IGaugeV3.sol";

// import {CreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/credit/CreditFacadeV3.sol";
// import {CreditConfiguratorV3} from "@gearbox-protocol/core-v3/contracts/credit/CreditConfiguratorV3.sol";
// import {creditManager} from "@gearbox-protocol/core-v3/contracts/credit/creditManager.sol";
// import {CreditManagerLiveMock} from "../mocks/credit/CreditManagerLiveMock.sol";
// import {Balance} from "@gearbox-protocol/core-v2/contracts/libraries/Balances.sol";
// import {IAdapter, AdapterType} from "../..//interfaces/IAdapter.sol";
// import {IConvexV1BoosterAdapter} from "../../interfaces/convex/IConvexV1BoosterAdapter.sol";

// import {CreditManagerOpts, CollateralToken} from "@gearbox-protocol/core-v3/contracts/credit/CreditConfiguratorV3.sol";

// import {DegenNFTV2} from "@gearbox-protocol/core-v2/contracts/tokens/DegenNFTV2.sol";

// import "../lib/constants.sol";

// import {CreditConfigLive, CreditManagerV3HumanOpts} from "../config/CreditConfigLive.sol";
// import {AdapterDeployer} from "./AdapterDeployer.sol";
import {Contracts, SupportedContracts} from "@gearbox-protocol/sdk/contracts/SupportedContracts.sol";

// address constant ADDRESS_PROVIDER = 0xcF64698AFF7E5f27A11dff868AF228653ba53be0;
// address constant ADDRESS_PROVIDER_GOERLI = 0x95f4cea53121b8A2Cb783C6BFB0915cEc44827D3;

// /// @title LiveEnvTestSuite
// /// @notice Test suite for mainnet test
// contract LiveEnvTestSuite is CreditConfigLive {
//     address public ROOT_ADDRESS;

//     AddressProvider public addressProvider;
//     ACL public acl;
//     TokensTestSuite public tokenTestSuite;
//     SupportedContracts public supportedContracts;
//     PriceOracleV3 public priceOracle;
//     GearStakingV3 public gearStaking;

//     Tokens[] supportedUnderlyings;

//     mapping(Tokens => PoolV3) public pools;

//     mapping(Tokens => creditManager[]) internal _CreditManagerV3s;
//     mapping(Tokens => CreditFacadeV3[]) internal _creditFacades;
//     mapping(Tokens => CreditConfiguratorV3[]) internal _CreditConfiguratorV3s;

//     mapping(Tokens => CreditManagerLiveMock) public CreditManagerV3Mocks;
//     mapping(Tokens => CreditFacadeV3) public creditFacadeMocks;
//     mapping(Tokens => CreditConfiguratorV3) public CreditConfiguratorV3Mocks;

//     DegenNFTV2 public degenNFT;

//     constructor() CreditConfigLive() {
//         if (block.chainid == 1337) {
//             uint8 networkId;
//             bool useExisting;
//             bool useExistingPools;

//             try vm.envInt("ETH_FORK_NETWORK_ID") returns (int256 val) {
//                 networkId = uint8(uint256(val));
//             } catch {
//                 networkId = 1;
//             }

//             try vm.envBool("ETH_FORK_USE_EXISTING") returns (bool val) {
//                 useExisting = val;
//             } catch {
//                 useExisting = false;
//             }

//             try vm.envBool("ETH_FORK_USE_EXISTING_POOLS") returns (bool val) {
//                 useExistingPools = val;
//             } catch {
//                 useExistingPools = false;
//             }

//             address ap = networkId == 1 ? ADDRESS_PROVIDER : networkId == 2 ? ADDRESS_PROVIDER_GOERLI : address(0);

//             supportedContracts = new SupportedContracts(networkId);
//             addressProvider = AddressProvider(ap);
//             acl = ACL(addressProvider.getACL());
//             ROOT_ADDRESS = acl.owner();
//             IDataCompressor dc = IDataCompressor(addressProvider.getDataCompressor());
//             ContractsRegister cr = ContractsRegister(addressProvider.getContractsRegister());
//             priceOracle = PriceOracleV3(addressProvider.getPriceOracle());

//             tokenTestSuite = new TokensTestSuite();

//             if (useExistingPools) {
//                 PoolData[] memory poolList = dc.getPoolsList();

//                 for (uint256 i = 0; i < poolList.length; ++i) {
//                     if (poolList[i].version == 3_00) {
//                         Tokens tu = tokenTestSuite.tokenIndexes(poolList[i].underlying);
//                         supportedUnderlyings.push(tu);
//                         pools[tu] = PoolV3(poolList[i].addr);

//                         {
//                             string memory underlyingSymbol = tokenTestSuite.symbols(tu);
//                             vm.label(address(pools[tu]), string(abi.encodePacked("POOL_", underlyingSymbol)));
//                         }

//                         if (address(gearStaking) == address(0)) {
//                             gearStaking = GearStakingV3(
//                                 address(IGaugeV3(IPoolQuotaKeeperV3(pools[tu].poolQuotaKeeper()).gauge()).voter())
//                             );

//                             vm.label(address(gearStaking), "GEAR_STAKING");
//                         }

//                         uint256 expectedLiquidityUSD =
//                             priceOracle.convertToUSD(pools[tu].expectedLiquidity(), poolList[i].underlying);
//                         if (expectedLiquidityUSD < 1_000_000 * 10 ** 8) {
//                             uint256 amountUSD = 1_000_000 * 10 ** 8 - expectedLiquidityUSD;
//                             uint256 amount = priceOracle.convertFromUSD(amountUSD, poolList[i].underlying);
//                             tokenTestSuite.mint(poolList[i].underlying, FRIEND, amount);
//                             tokenTestSuite.approve(poolList[i].underlying, FRIEND, address(pools[tu]));

//                             vm.prank(FRIEND);
//                             pools[tu].deposit(amount, FRIEND);
//                         }
//                     }
//                 }
//             } else {
//                 LivePoolDeployer pd = new LivePoolDeployer(
//                     address(addressProvider),
//                     tokenTestSuite,
//                     ROOT_ADDRESS
//                 );

//                 gearStaking = pd.gearStaking();
//                 vm.label(address(gearStaking), "GEAR_STAKING");

//                 PoolV3[] memory deployedPools = pd.pools();

//                 for (uint256 i = 0; i < deployedPools.length; ++i) {
//                     address underlying = deployedPools[i].underlyingToken();

//                     Tokens t = tokenTestSuite.tokenIndexes(underlying);
//                     supportedUnderlyings.push(t);

//                     pools[t] = deployedPools[i];

//                     {
//                         string memory underlyingSymbol = tokenTestSuite.symbols(t);
//                         vm.label(address(pools[t]), string(abi.encodePacked("POOL_", underlyingSymbol)));
//                     }

//                     tokenTestSuite.mint(underlying, FRIEND, pools[t].expectedLiquidityLimit() / 3);

//                     tokenTestSuite.approve(underlying, FRIEND, address(pools[t]));

//                     vm.startPrank(FRIEND);
//                     pools[t].deposit(pools[t].expectedLiquidityLimit() / 3, FRIEND);
//                     vm.stopPrank();
//                 }
//             }

//             if (useExisting) {
//                 CreditManagerV3Data[] memory cmList = dc.getCreditManagerV3sList();

//                 bool mintedNFT = false;

//                 for (uint256 i = 0; i < cmList.length; ++i) {
//                     if (cmList[i].version == 3_00) {
//                         Tokens underlyingT = tokenTestSuite.tokenIndexes(cmList[i].underlying);

//                         _CreditManagerV3s[underlyingT].push(creditManager(cmList[i].addr));
//                         _creditFacades[underlyingT].push(CreditFacadeV3(cmList[i].creditFacade));
//                         _CreditConfiguratorV3s[underlyingT].push(CreditConfiguratorV3(cmList[i].CreditConfiguratorV3));

//                         if (CreditFacadeV3(cmList[i].creditFacade).whitelisted() && !mintedNFT) {
//                             DegenNFTV2 dnft = DegenNFTV2(CreditFacadeV3(cmList[i].creditFacade).degenNFT());

//                             vm.prank(dnft.minter());
//                             dnft.mint(USER, 30);
//                             mintedNFT = true;
//                         }

//                         if (
//                             address(blacklistHelper) == address(0)
//                                 && CreditFacadeV3(cmList[i].creditFacade).blacklistHelper() != address(0)
//                         ) {
//                             blacklistHelper = BlacklistHelper(CreditFacadeV3(cmList[i].creditFacade).blacklistHelper());
//                         }

//                         string memory underlyingSymbol = tokenTestSuite.symbols(underlyingT);
//                         uint256 CM_num = _CreditManagerV3s[underlyingT].length;

//                         vm.label(
//                             cmList[i].creditFacade,
//                             string(abi.encodePacked("CREDIT_FACADE_", underlyingSymbol, "_", CM_num))
//                         );
//                         vm.label(
//                             cmList[i].addr, string(abi.encodePacked("CREDIT_MANAGER_", underlyingSymbol, "_", CM_num))
//                         );
//                         vm.label(
//                             cmList[i].CreditConfiguratorV3,
//                             string(abi.encodePacked("CREDIT_CONFIGURATOR_", underlyingSymbol, "_", CM_num))
//                         );
//                     }
//                 }
//             } else {
//                 PriceFeedDeployer priceFeedDeployer = new PriceFeedDeployer(
//                     networkId,
//                     ap,
//                     tokenTestSuite,
//                     supportedContracts
//                 );

//                 priceOracle = new PriceOracleV3(
//                     ap,
//                     priceFeedDeployer.getPriceFeeds()
//                 );

//                 blacklistHelper = new BlacklistHelper(
//                     ap,
//                     tokenTestSuite.addressOf(Tokens.USDC),
//                     tokenTestSuite.addressOf(Tokens.USDT)
//                 );

//                 vm.prank(ROOT_ADDRESS);
//                 addressProvider.setPriceOracle(address(priceOracle));

//                 ContractsRegister cr = ContractsRegister(addressProvider.getContractsRegister());

//                 uint256 len = numOpts;
//                 unchecked {
//                     for (uint256 i = 0; i < len; ++i) {
//                         Tokens underlyingT = CreditManagerV3HumanOpts[i].underlying;

//                         if (address(pools[underlyingT]) == address(0)) continue;

//                         // REAL CREDIT MANAGERS
//                         {
//                             address underlying = tokenTestSuite.addressOf(underlyingT);

//                             (CreditManagerOpts memory cmOpts, Contracts[] memory adaptersList) =
//                                 getCreditManagerV3Config(i);

//                             if (
//                                 (underlyingT == Tokens.USDC || underlyingT == Tokens.USDT)
//                                     && cmOpts.blacklistHelper == address(0)
//                             ) {
//                                 cmOpts.blacklistHelper = address(blacklistHelper);
//                             } else if (cmOpts.blacklistHelper != address(0)) {
//                                 blacklistHelper = BlacklistHelper(cmOpts.blacklistHelper);
//                             }

//                             CreditManagerV3Factory cmf = new CreditManagerV3Factory(
//                                 address(pools[underlyingT]),
//                                 cmOpts,
//                                 0
//                             );

//                             string memory underlyingSymbol = tokenTestSuite.symbols(underlyingT);

//                             AdapterDeployer ad = new AdapterDeployer(
//                                 address(cmf.creditManager()),
//                                 adaptersList,
//                                 tokenTestSuite,
//                                 supportedContracts,
//                                 string(
//                                     abi.encodePacked(
//                                         "CM_",
//                                         underlyingSymbol,
//                                         "_"
//                                     )
//                                 )
//                             );
//                             cmf.addAdapters(ad.getAdapters());

//                             vm.prank(ROOT_ADDRESS);
//                             acl.transferOwnership(address(cmf));
//                             cmf.configure();

//                             uint256 CM_num = _CreditManagerV3s[underlyingT].length;

//                             vm.label(
//                                 address(cmf.creditFacade()),
//                                 string(abi.encodePacked("CREDIT_FACADE_", underlyingSymbol, "_", CM_num))
//                             );
//                             vm.label(
//                                 address(cmf.creditManager()),
//                                 string(abi.encodePacked("CREDIT_MANAGER_", underlyingSymbol, "_", CM_num))
//                             );
//                             vm.label(
//                                 address(cmf.CreditConfiguratorV3()),
//                                 string(abi.encodePacked("CREDIT_CONFIGURATOR_", underlyingSymbol, "_", CM_num))
//                             );

//                             _CreditManagerV3s[underlyingT].push(cmf.creditManager());
//                             _creditFacades[underlyingT].push(cmf.creditFacade());
//                             _CreditConfiguratorV3s[underlyingT].push(cmf.CreditConfiguratorV3());

//                             BotListV3 botList = new BotListV3(ap);

//                             vm.startPrank(ROOT_ADDRESS);
//                             cmf.CreditConfiguratorV3().setBotListV3(address(botList));
//                             if (cmf.creditFacade().isBlacklistableUnderlying()) {
//                                 blacklistHelper.addCreditFacadeV3(address(cmf.creditFacade()));
//                             }
//                             vm.stopPrank();

//                             _setLimitedTokens(cmf.creditManager());

//                             _configureConvexPhantomTokens(address(cmf.creditManager()));
//                         }

//                         // MOCK CREDIT MANAGERS
//                         // Mock credit managers skip health checks
//                         if (address(CreditManagerV3Mocks[underlyingT]) != address(0)) {
//                             address underlying = tokenTestSuite.addressOf(underlyingT);

//                             (CreditManagerOpts memory cmOpts, Contracts[] memory adaptersList) =
//                                 getCreditManagerV3Config(i);

//                             CreditManagerV3MockFactory cmf = new CreditManagerV3MockFactory(
//                                     address(pools[underlyingT]),
//                                     cmOpts,
//                                     0
//                                 );

//                             string memory underlyingSymbol = tokenTestSuite.symbols(underlyingT);

//                             AdapterDeployer ad = new AdapterDeployer(
//                                 address(cmf.creditManager()),
//                                 adaptersList,
//                                 tokenTestSuite,
//                                 supportedContracts,
//                                 string(
//                                     abi.encodePacked(
//                                         "CM_MOCK_",
//                                         underlyingSymbol,
//                                         "_"
//                                     )
//                                 )
//                             );
//                             cmf.addAdapters(ad.getAdapters());

//                             vm.prank(ROOT_ADDRESS);
//                             acl.transferOwnership(address(cmf));
//                             cmf.configure();

//                             vm.label(
//                                 address(cmf.creditFacade()),
//                                 string(abi.encodePacked("CREDIT_FACADE_MOCK_", underlyingSymbol))
//                             );
//                             vm.label(
//                                 address(cmf.creditManager()),
//                                 string(abi.encodePacked("CREDIT_MANAGER_MOCK_", underlyingSymbol))
//                             );
//                             vm.label(
//                                 address(cmf.CreditConfiguratorV3()),
//                                 string(abi.encodePacked("CREDIT_CONFIGURATOR_MOCK_", underlyingSymbol))
//                             );

//                             CreditManagerV3Mocks[underlyingT] = cmf.creditManager();
//                             creditFacadeMocks[underlyingT] = cmf.creditFacade();
//                             CreditConfiguratorV3Mocks[underlyingT] = cmf.CreditConfiguratorV3();

//                             _configureConvexPhantomTokens(address(cmf.creditManager()));
//                         }
//                     }
//                 }
//             }
//         }
//     }

//     function _configureConvexPhantomTokens(address creditManager) internal {
//         address[] memory adapters = getAdapters(creditManager);
//         uint256 len = adapters.length;

//         vm.startPrank(ROOT_ADDRESS);
//         for (uint256 i = 0; i < len; ++i) {
//             if (adapters[i] == address(0)) continue;
//             AdapterType aType = IAdapter(adapters[i])._gearboxAdapterType();
//             if (aType == AdapterType.CONVEX_V1_BOOSTER) {
//                 IConvexV1BoosterAdapter(adapters[i]).updateStakedPhantomTokensMap();
//             }
//         }
//         vm.stopPrank();
//     }

//     function _setLimitedTokens(creditManager creditManager) internal {
//         PoolV3 pool = PoolV3(creditManager.pool());
//         IPoolQuotaKeeperV3 pqk = IPoolQuotaKeeperV3(pool.poolQuotaKeeper());

//         address[] memory quotedTokens = pqk.quotedTokens();

//         CreditConfiguratorV3 cc = CreditConfiguratorV3(creditManager.CreditConfiguratorV3());

//         for (uint256 i = 0; i < quotedTokens.length; ++i) {
//             if (creditManager.getTokenMaskOrRevert(quotedTokens[i]) != 0) {
//                 vm.prank(ROOT_ADDRESS);
//                 cc.makeTokenLimited(quotedTokens[i]);
//             }
//         }
//     }

//     function CreditManagerV3s(Tokens t) external view returns (creditManager) {
//         return _CreditManagerV3s[t][0];
//     }

//     function CreditManagerV3s(Tokens t, uint256 idx) external view returns (creditManager) {
//         return _CreditManagerV3s[t][idx];
//     }

//     function creditFacades(Tokens t) external view returns (CreditFacadeV3) {
//         return _creditFacades[t][0];
//     }

//     function creditFacades(Tokens t, uint256 idx) external view returns (CreditFacadeV3) {
//         return _creditFacades[t][idx];
//     }

//     function CreditConfiguratorV3s(Tokens t) external view returns (CreditConfiguratorV3) {
//         return _CreditConfiguratorV3s[t][0];
//     }

//     function CreditConfiguratorV3s(Tokens t, uint256 idx) external view returns (CreditConfiguratorV3) {
//         return _CreditConfiguratorV3s[t][idx];
//     }

//     function getCreditManagerV3Config(uint256 idx)
//         internal
//         view
//         returns (CreditManagerOpts memory cmOpts, Contracts[] memory adaptersList)
//     {
//         CreditManagerV3HumanOpts memory humanCfg = CreditManagerV3HumanOpts[idx];

//         uint256 len = humanCfg.collateralTokens.length;

//         cmOpts.collateralTokens = new CollateralToken[](len);
//         unchecked {
//             for (uint256 i; i < len; ++i) {
//                 cmOpts.collateralTokens[i] = CollateralToken({
//                     token: tokenTestSuite.addressOf(humanCfg.collateralTokens[i].token),
//                     liquidationThreshold: humanCfg.collateralTokens[i].liquidationThreshold
//                 });
//             }
//         }
//         cmOpts.minBorrowedAmount = humanCfg.minBorrowedAmount;
//         cmOpts.maxBorrowedAmount = humanCfg.maxBorrowedAmount;
//         cmOpts.degenNFT = humanCfg.degenNFT;
//         cmOpts.expirable = humanCfg.expirable;
//         adaptersList = humanCfg.contracts;
//     }

//     function getMockAdapter(Tokens underlying, Contracts target) public view returns (address) {
//         return CreditManagerV3Mocks[underlying].contractToAdapter(supportedContracts.addressOf(target));
//     }

// function getAdapters(address creditManager) public view returns (address[] memory adapters) {
//     uint256 contractCount = supportedContracts.contractCount();

//     adapters = new address[](contractCount);

//     for (uint256 i = 0; i < contractCount; ++i) {
//         adapters[i] = getAdapter(creditManager, Contracts(i));
//     }
// }

// function getAdapters(Tokens underlying) public view returns (address[] memory adapters) {
//     uint256 contractCount = supportedContracts.contractCount();

//     adapters = new address[](contractCount);

//     for (uint256 i = 0; i < contractCount; ++i) {
//         adapters[i] = getAdapter(underlying, Contracts(i));
//     }
// }

// function getAdapters(Tokens underlying, uint256 cmIdx) public view returns (address[] memory adapters) {
//     uint256 contractCount = supportedContracts.contractCount();

//     adapters = new address[](contractCount);

//     for (uint256 i = 0; i < contractCount; ++i) {
//         adapters[i] = getAdapter(underlying, Contracts(i), cmIdx);
//     }
// }

//     function getBalances() public view returns (Balance[] memory balances) {
//         uint256 tokenCount = uint256(type(Tokens).max);

//         balances = new Balance[](tokenCount);

//         for (uint256 i = 0; i < tokenCount; ++i) {
//             balances[i].token = tokenTestSuite.addressOf(Tokens(i));
//         }
//     }

//     function getSupportedUnderlyings() public view returns (Tokens[] memory) {
//         return supportedUnderlyings;
//     }
// }
