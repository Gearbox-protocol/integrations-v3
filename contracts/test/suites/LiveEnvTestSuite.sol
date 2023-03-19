// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {Tokens} from "../config/Tokens.sol";
import {TokensTestSuite} from "./TokensTestSuite.sol";
import {LivePriceFeedDeployer} from "./LivePriceFeedDeployer.sol";
import {IDataCompressor} from "@gearbox-protocol/core-v2/contracts/interfaces/IDataCompressor.sol";
import {CreditManagerData, PoolData} from "@gearbox-protocol/core-v2/contracts/libraries/Types.sol";

import {AddressProvider} from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";

import {ACL} from "@gearbox-protocol/core-v2/contracts/core/ACL.sol";
import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";
import {PriceOracle} from "@gearbox-protocol/core-v2/contracts/oracles/PriceOracle.sol";
import {IPoolService} from "@gearbox-protocol/core-v2/contracts/interfaces/IPoolService.sol";
import {Pool4626} from "@gearbox-protocol/core-v3/contracts/pool/Pool4626.sol";
import {GearStaking} from "@gearbox-protocol/core-v3/contracts/support/GearStaking.sol";
import {BlacklistHelper} from "@gearbox-protocol/core-v3/contracts/support/BlacklistHelper.sol";
import {BotList} from "@gearbox-protocol/core-v3/contracts/support/BotList.sol";
import {IPoolQuotaKeeper} from "@gearbox-protocol/core-v3/contracts/interfaces/IPoolQuotaKeeper.sol";
import {IGauge} from "@gearbox-protocol/core-v3/contracts/interfaces/IGauge.sol";

import {CreditFacade} from "@gearbox-protocol/core-v3/contracts/credit/CreditFacade.sol";
import {CreditConfigurator} from "@gearbox-protocol/core-v3/contracts/credit/CreditConfigurator.sol";
import {CreditManager} from "@gearbox-protocol/core-v3/contracts/credit/CreditManager.sol";
import {CreditManagerLiveMock} from "../mocks/credit/CreditManagerLiveMock.sol";
import {Balance} from "@gearbox-protocol/core-v2/contracts/libraries/Balances.sol";
import {IAdapter, AdapterType} from "@gearbox-protocol/core-v3/contracts/interfaces/adapters/IAdapter.sol";
import {IConvexV1BoosterAdapter} from "../../interfaces/convex/IConvexV1BoosterAdapter.sol";

import {CreditManagerFactory} from "../../factories/CreditManagerFactory.sol";
import {CreditManagerMockFactory} from "../mocks/credit/CreditManagerMockFactory.sol";
import {CreditManagerOpts, CollateralToken} from "@gearbox-protocol/core-v3/contracts/credit/CreditConfigurator.sol";
import {WstETHPoolSetup} from "./WstETHPoolSetup.sol";

import {DegenNFT} from "@gearbox-protocol/core-v2/contracts/tokens/DegenNFT.sol";

import "../lib/constants.sol";

import {CreditConfigLive, CreditManagerHumanOpts} from "../config/CreditConfigLive.sol";
import {AdapterDeployer} from "./AdapterDeployer.sol";
import {Contracts, SupportedContracts} from "../config/SupportedContracts.sol";
import {LivePoolDeployer} from "./PoolDeployer.sol";

address constant ADDRESS_PROVIDER = 0xcF64698AFF7E5f27A11dff868AF228653ba53be0;
address constant ADDRESS_PROVIDER_GOERLI = 0x95f4cea53121b8A2Cb783C6BFB0915cEc44827D3;

/// @title LiveEnvTestSuite
/// @notice Test suite for mainnet test
contract LiveEnvTestSuite is CreditConfigLive {
    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    address public ROOT_ADDRESS;

    AddressProvider public addressProvider;
    ACL public acl;
    TokensTestSuite public tokenTestSuite;
    SupportedContracts public supportedContracts;
    PriceOracle public priceOracle;
    GearStaking public gearStaking;
    BlacklistHelper public blacklistHelper;

    Tokens[] supportedUnderlyings;

    mapping(Tokens => Pool4626) public pools;

    mapping(Tokens => CreditManager[]) internal _creditManagers;
    mapping(Tokens => CreditFacade[]) internal _creditFacades;
    mapping(Tokens => CreditConfigurator[]) internal _creditConfigurators;

    mapping(Tokens => CreditManagerLiveMock) public creditManagerMocks;
    mapping(Tokens => CreditFacade) public creditFacadeMocks;
    mapping(Tokens => CreditConfigurator) public creditConfiguratorMocks;

    DegenNFT public degenNFT;

    constructor() CreditConfigLive() {
        if (block.chainid == 1337) {
            uint8 networkId;
            bool useExisting;
            bool useExistingPools;

            try evm.envInt("ETH_FORK_NETWORK_ID") returns (int256 val) {
                networkId = uint8(uint256(val));
            } catch {
                networkId = 1;
            }

            try evm.envBool("ETH_FORK_USE_EXISTING") returns (bool val) {
                useExisting = val;
            } catch {
                useExisting = false;
            }

            try evm.envBool("ETH_FORK_USE_EXISTING_POOLS") returns (bool val) {
                useExistingPools = val;
            } catch {
                useExistingPools = false;
            }

            address ap = networkId == 1 ? ADDRESS_PROVIDER : networkId == 2 ? ADDRESS_PROVIDER_GOERLI : address(0);

            supportedContracts = new SupportedContracts(networkId);
            addressProvider = AddressProvider(ap);
            acl = ACL(addressProvider.getACL());
            ROOT_ADDRESS = acl.owner();
            IDataCompressor dc = IDataCompressor(addressProvider.getDataCompressor());
            ContractsRegister cr = ContractsRegister(addressProvider.getContractsRegister());
            priceOracle = PriceOracle(addressProvider.getPriceOracle());

            tokenTestSuite = new TokensTestSuite();

            if (useExistingPools) {
                PoolData[] memory poolList = dc.getPoolsList();

                for (uint256 i = 0; i < poolList.length; ++i) {
                    if (poolList[i].version == 3_00) {
                        Tokens tu = tokenTestSuite.tokenIndexes(poolList[i].underlying);
                        supportedUnderlyings.push(tu);
                        pools[tu] = Pool4626(poolList[i].addr);

                        {
                            string memory underlyingSymbol = tokenTestSuite.symbols(tu);
                            evm.label(address(pools[tu]), string(abi.encodePacked("POOL_", underlyingSymbol)));
                        }

                        if (address(gearStaking) == address(0)) {
                            gearStaking = GearStaking(
                                address(IGauge(IPoolQuotaKeeper(pools[tu].poolQuotaKeeper()).gauge()).voter())
                            );

                            evm.label(address(gearStaking), "GEAR_STAKING");
                        }

                        uint256 expectedLiquidityUSD =
                            priceOracle.convertToUSD(pools[tu].expectedLiquidity(), poolList[i].underlying);
                        if (expectedLiquidityUSD < 1_000_000 * 10 ** 8) {
                            uint256 amountUSD = 1_000_000 * 10 ** 8 - expectedLiquidityUSD;
                            uint256 amount = priceOracle.convertFromUSD(amountUSD, poolList[i].underlying);
                            tokenTestSuite.mint(poolList[i].underlying, FRIEND, amount);
                            tokenTestSuite.approve(poolList[i].underlying, FRIEND, address(pools[tu]));

                            evm.prank(FRIEND);
                            pools[tu].deposit(amount, FRIEND);
                        }
                    }
                }
            } else {
                LivePoolDeployer pd = new LivePoolDeployer(
                    address(addressProvider),
                    tokenTestSuite,
                    ROOT_ADDRESS
                );

                gearStaking = pd.gearStaking();
                evm.label(address(gearStaking), "GEAR_STAKING");

                Pool4626[] memory deployedPools = pd.pools();

                for (uint256 i = 0; i < deployedPools.length; ++i) {
                    address underlying = deployedPools[i].underlyingToken();

                    Tokens t = tokenTestSuite.tokenIndexes(underlying);
                    supportedUnderlyings.push(t);

                    pools[t] = deployedPools[i];

                    {
                        string memory underlyingSymbol = tokenTestSuite.symbols(t);
                        evm.label(address(pools[t]), string(abi.encodePacked("POOL_", underlyingSymbol)));
                    }

                    tokenTestSuite.mint(underlying, FRIEND, pools[t].expectedLiquidityLimit() / 3);

                    tokenTestSuite.approve(underlying, FRIEND, address(pools[t]));

                    evm.startPrank(FRIEND);
                    pools[t].deposit(pools[t].expectedLiquidityLimit() / 3, FRIEND);
                    evm.stopPrank();
                }
            }

            if (useExisting) {
                CreditManagerData[] memory cmList = dc.getCreditManagersList();

                bool mintedNFT = false;

                for (uint256 i = 0; i < cmList.length; ++i) {
                    if (cmList[i].version == 3_00) {
                        Tokens underlyingT = tokenTestSuite.tokenIndexes(cmList[i].underlying);

                        _creditManagers[underlyingT].push(CreditManager(cmList[i].addr));
                        _creditFacades[underlyingT].push(CreditFacade(cmList[i].creditFacade));
                        _creditConfigurators[underlyingT].push(CreditConfigurator(cmList[i].creditConfigurator));

                        if (CreditFacade(cmList[i].creditFacade).whitelisted() && !mintedNFT) {
                            DegenNFT dnft = DegenNFT(CreditFacade(cmList[i].creditFacade).degenNFT());

                            evm.prank(dnft.minter());
                            dnft.mint(USER, 30);
                            mintedNFT = true;
                        }

                        if (
                            address(blacklistHelper) == address(0)
                                && CreditFacade(cmList[i].creditFacade).blacklistHelper() != address(0)
                        ) {
                            blacklistHelper = BlacklistHelper(CreditFacade(cmList[i].creditFacade).blacklistHelper());
                        }

                        string memory underlyingSymbol = tokenTestSuite.symbols(underlyingT);
                        uint256 CM_num = _creditManagers[underlyingT].length;

                        evm.label(
                            cmList[i].creditFacade,
                            string(abi.encodePacked("CREDIT_FACADE_", underlyingSymbol, "_", CM_num))
                        );
                        evm.label(
                            cmList[i].addr, string(abi.encodePacked("CREDIT_MANAGER_", underlyingSymbol, "_", CM_num))
                        );
                        evm.label(
                            cmList[i].creditConfigurator,
                            string(abi.encodePacked("CREDIT_CONFIGURATOR_", underlyingSymbol, "_", CM_num))
                        );
                    }
                }
            } else {
                LivePriceFeedDeployer priceFeedDeployer = new LivePriceFeedDeployer(
                    networkId,
                    ap,
                    tokenTestSuite,
                    supportedContracts
                );

                priceOracle = new PriceOracle(
                    ap,
                    priceFeedDeployer.getPriceFeeds()
                );

                blacklistHelper = new BlacklistHelper(
                    ap,
                    tokenTestSuite.addressOf(Tokens.USDC),
                    tokenTestSuite.addressOf(Tokens.USDT)
                );

                evm.prank(ROOT_ADDRESS);
                addressProvider.setPriceOracle(address(priceOracle));

                ContractsRegister cr = ContractsRegister(addressProvider.getContractsRegister());

                uint256 len = numOpts;
                unchecked {
                    for (uint256 i = 0; i < len; ++i) {
                        Tokens underlyingT = creditManagerHumanOpts[i].underlying;

                        if (address(pools[underlyingT]) == address(0)) continue;

                        // REAL CREDIT MANAGERS
                        {
                            address underlying = tokenTestSuite.addressOf(underlyingT);

                            (CreditManagerOpts memory cmOpts, Contracts[] memory adaptersList) =
                                getCreditManagerConfig(i);

                            if (
                                (underlyingT == Tokens.USDC || underlyingT == Tokens.USDT)
                                    && cmOpts.blacklistHelper == address(0)
                            ) {
                                cmOpts.blacklistHelper = address(blacklistHelper);
                            } else if (cmOpts.blacklistHelper != address(0)) {
                                blacklistHelper = BlacklistHelper(cmOpts.blacklistHelper);
                            }

                            CreditManagerFactory cmf = new CreditManagerFactory(
                                address(pools[underlyingT]),
                                cmOpts,
                                0
                            );

                            string memory underlyingSymbol = tokenTestSuite.symbols(underlyingT);

                            AdapterDeployer ad = new AdapterDeployer(
                                address(cmf.creditManager()),
                                adaptersList,
                                tokenTestSuite,
                                supportedContracts,
                                string(
                                    abi.encodePacked(
                                        "CM_",
                                        underlyingSymbol,
                                        "_"
                                    )
                                )
                            );
                            cmf.addAdapters(ad.getAdapters());

                            evm.prank(ROOT_ADDRESS);
                            acl.transferOwnership(address(cmf));
                            cmf.configure();

                            uint256 CM_num = _creditManagers[underlyingT].length;

                            evm.label(
                                address(cmf.creditFacade()),
                                string(abi.encodePacked("CREDIT_FACADE_", underlyingSymbol, "_", CM_num))
                            );
                            evm.label(
                                address(cmf.creditManager()),
                                string(abi.encodePacked("CREDIT_MANAGER_", underlyingSymbol, "_", CM_num))
                            );
                            evm.label(
                                address(cmf.creditConfigurator()),
                                string(abi.encodePacked("CREDIT_CONFIGURATOR_", underlyingSymbol, "_", CM_num))
                            );

                            _creditManagers[underlyingT].push(cmf.creditManager());
                            _creditFacades[underlyingT].push(cmf.creditFacade());
                            _creditConfigurators[underlyingT].push(cmf.creditConfigurator());

                            BotList botList = new BotList(ap);

                            evm.startPrank(ROOT_ADDRESS);
                            cmf.creditConfigurator().setBotList(address(botList));
                            if (cmf.creditFacade().isBlacklistableUnderlying()) {
                                blacklistHelper.addCreditFacade(address(cmf.creditFacade()));
                            }
                            evm.stopPrank();

                            _setLimitedTokens(cmf.creditManager());

                            _configureConvexPhantomTokens(address(cmf.creditManager()));
                        }

                        // MOCK CREDIT MANAGERS
                        // Mock credit managers skip health checks
                        if (address(creditManagerMocks[underlyingT]) != address(0)) {
                            address underlying = tokenTestSuite.addressOf(underlyingT);

                            (CreditManagerOpts memory cmOpts, Contracts[] memory adaptersList) =
                                getCreditManagerConfig(i);

                            CreditManagerMockFactory cmf = new CreditManagerMockFactory(
                                    address(pools[underlyingT]),
                                    cmOpts,
                                    0
                                );

                            string memory underlyingSymbol = tokenTestSuite.symbols(underlyingT);

                            AdapterDeployer ad = new AdapterDeployer(
                                address(cmf.creditManager()),
                                adaptersList,
                                tokenTestSuite,
                                supportedContracts,
                                string(
                                    abi.encodePacked(
                                        "CM_MOCK_",
                                        underlyingSymbol,
                                        "_"
                                    )
                                )
                            );
                            cmf.addAdapters(ad.getAdapters());

                            evm.prank(ROOT_ADDRESS);
                            acl.transferOwnership(address(cmf));
                            cmf.configure();

                            evm.label(
                                address(cmf.creditFacade()),
                                string(abi.encodePacked("CREDIT_FACADE_MOCK_", underlyingSymbol))
                            );
                            evm.label(
                                address(cmf.creditManager()),
                                string(abi.encodePacked("CREDIT_MANAGER_MOCK_", underlyingSymbol))
                            );
                            evm.label(
                                address(cmf.creditConfigurator()),
                                string(abi.encodePacked("CREDIT_CONFIGURATOR_MOCK_", underlyingSymbol))
                            );

                            creditManagerMocks[underlyingT] = cmf.creditManager();
                            creditFacadeMocks[underlyingT] = cmf.creditFacade();
                            creditConfiguratorMocks[underlyingT] = cmf.creditConfigurator();

                            _configureConvexPhantomTokens(address(cmf.creditManager()));
                        }
                    }
                }
            }
        }
    }

    function _configureConvexPhantomTokens(address creditManager) internal {
        address[] memory adapters = getAdapters(creditManager);
        uint256 len = adapters.length;

        evm.startPrank(ROOT_ADDRESS);
        for (uint256 i = 0; i < len; ++i) {
            if (adapters[i] == address(0)) continue;
            AdapterType aType = IAdapter(adapters[i])._gearboxAdapterType();
            if (aType == AdapterType.CONVEX_V1_BOOSTER) {
                IConvexV1BoosterAdapter(adapters[i]).updateStakedPhantomTokensMap();
            }
        }
        evm.stopPrank();
    }

    function _setLimitedTokens(CreditManager creditManager) internal {
        Pool4626 pool = Pool4626(creditManager.pool());
        IPoolQuotaKeeper pqk = IPoolQuotaKeeper(pool.poolQuotaKeeper());

        address[] memory quotedTokens = pqk.quotedTokens();

        CreditConfigurator cc = CreditConfigurator(creditManager.creditConfigurator());

        for (uint256 i = 0; i < quotedTokens.length; ++i) {
            if (creditManager.tokenMasksMap(quotedTokens[i]) != 0) {
                evm.prank(ROOT_ADDRESS);
                cc.makeTokenLimited(quotedTokens[i]);
            }
        }
    }

    function creditManagers(Tokens t) external view returns (CreditManager) {
        return _creditManagers[t][0];
    }

    function creditManagers(Tokens t, uint256 idx) external view returns (CreditManager) {
        return _creditManagers[t][idx];
    }

    function creditFacades(Tokens t) external view returns (CreditFacade) {
        return _creditFacades[t][0];
    }

    function creditFacades(Tokens t, uint256 idx) external view returns (CreditFacade) {
        return _creditFacades[t][idx];
    }

    function creditConfigurators(Tokens t) external view returns (CreditConfigurator) {
        return _creditConfigurators[t][0];
    }

    function creditConfigurators(Tokens t, uint256 idx) external view returns (CreditConfigurator) {
        return _creditConfigurators[t][idx];
    }

    function getCreditManagerConfig(uint256 idx)
        internal
        view
        returns (CreditManagerOpts memory cmOpts, Contracts[] memory adaptersList)
    {
        CreditManagerHumanOpts memory humanCfg = creditManagerHumanOpts[idx];

        uint256 len = humanCfg.collateralTokens.length;

        cmOpts.collateralTokens = new CollateralToken[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                cmOpts.collateralTokens[i] = CollateralToken({
                    token: tokenTestSuite.addressOf(humanCfg.collateralTokens[i].token),
                    liquidationThreshold: humanCfg.collateralTokens[i].liquidationThreshold
                });
            }
        }
        cmOpts.minBorrowedAmount = humanCfg.minBorrowedAmount;
        cmOpts.maxBorrowedAmount = humanCfg.maxBorrowedAmount;
        cmOpts.degenNFT = humanCfg.degenNFT;
        cmOpts.expirable = humanCfg.expirable;
        adaptersList = humanCfg.contracts;
    }

    function getAdapter(address creditManager, Contracts target) public view returns (address) {
        return CreditManager(creditManager).contractToAdapter(supportedContracts.addressOf(target));
    }

    function getAdapter(Tokens underlying, Contracts target) public view returns (address) {
        return _creditManagers[underlying][0].contractToAdapter(supportedContracts.addressOf(target));
    }

    function getAdapter(Tokens underlying, Contracts target, uint256 cmIdx) public view returns (address) {
        return _creditManagers[underlying][cmIdx].contractToAdapter(supportedContracts.addressOf(target));
    }

    function getMockAdapter(Tokens underlying, Contracts target) public view returns (address) {
        return creditManagerMocks[underlying].contractToAdapter(supportedContracts.addressOf(target));
    }

    function getAdapters(address creditManager) public view returns (address[] memory adapters) {
        uint256 contractCount = supportedContracts.contractCount();

        adapters = new address[](contractCount);

        for (uint256 i = 0; i < contractCount; ++i) {
            adapters[i] = getAdapter(creditManager, Contracts(i));
        }
    }

    function getAdapters(Tokens underlying) public view returns (address[] memory adapters) {
        uint256 contractCount = supportedContracts.contractCount();

        adapters = new address[](contractCount);

        for (uint256 i = 0; i < contractCount; ++i) {
            adapters[i] = getAdapter(underlying, Contracts(i));
        }
    }

    function getAdapters(Tokens underlying, uint256 cmIdx) public view returns (address[] memory adapters) {
        uint256 contractCount = supportedContracts.contractCount();

        adapters = new address[](contractCount);

        for (uint256 i = 0; i < contractCount; ++i) {
            adapters[i] = getAdapter(underlying, Contracts(i), cmIdx);
        }
    }

    function getBalances() public view returns (Balance[] memory balances) {
        uint256 tokenCount = uint256(type(Tokens).max);

        balances = new Balance[](tokenCount);

        for (uint256 i = 0; i < tokenCount; ++i) {
            balances[i].token = tokenTestSuite.addressOf(Tokens(i));
        }
    }

    function getSupportedUnderlyings() public view returns (Tokens[] memory) {
        return supportedUnderlyings;
    }
}
