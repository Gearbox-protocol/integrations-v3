// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {Tokens} from "../config/Tokens.sol";
import {TokensTestSuite} from "./TokensTestSuite.sol";
import {LivePriceFeedDeployer} from "./LivePriceFeedDeployer.sol";
import {IDataCompressor} from "@gearbox-protocol/core-v2/contracts/interfaces/IDataCompressor.sol";
import {CreditManagerData} from "@gearbox-protocol/core-v2/contracts/libraries/Types.sol";
import {AddressList} from "@gearbox-protocol/core-v2/contracts/libraries/AddressList.sol";

import {AddressProvider} from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";

import {ACL} from "@gearbox-protocol/core-v2/contracts/core/ACL.sol";
import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";
import {PriceOracle} from "@gearbox-protocol/core-v2/contracts/oracles/PriceOracle.sol";
import {IPoolService} from "@gearbox-protocol/core-v2/contracts/interfaces/IPoolService.sol";

import {CreditFacade} from "@gearbox-protocol/core-v2/contracts/credit/CreditFacade.sol";
import {CreditConfigurator} from "@gearbox-protocol/core-v2/contracts/credit/CreditConfigurator.sol";
import {CreditManager} from "@gearbox-protocol/core-v2/contracts/credit/CreditManager.sol";
import {CreditManagerLiveMock} from "../mocks/credit/CreditManagerLiveMock.sol";
import {Balance} from "@gearbox-protocol/core-v2/contracts/libraries/Balances.sol";
import {IAdapter, AdapterType} from "@gearbox-protocol/core-v2/contracts/interfaces/adapters/IAdapter.sol";
import {IConvexV1BoosterAdapter} from "../../interfaces/convex/IConvexV1BoosterAdapter.sol";
import {BalancerV2VaultAdapter} from "../../adapters/balancer/BalancerV2VaultAdapter.sol";
import {UniswapV2Adapter} from "../../adapters/uniswap/UniswapV2.sol";
import {UniswapV3Adapter} from "../../adapters/uniswap/UniswapV3.sol";
import {UniswapPairStatus} from "../../interfaces/uniswap/IUniswapV2Adapter.sol";
import {UniswapV3PoolStatus} from "../../interfaces/uniswap/IUniswapV3Adapter.sol";
import {BlacklistHelper} from "@gearbox-protocol/core-v2/contracts/support/BlacklistHelper.sol";
import {PoolService} from "@gearbox-protocol/core-v2/contracts/pool/PoolService.sol";

import {CreditManagerFactory} from "../../factories/CreditManagerFactory.sol";
import {CreditManagerMockFactory} from "../mocks/credit/CreditManagerMockFactory.sol";
import {CreditManagerOpts, CollateralToken} from "@gearbox-protocol/core-v2/contracts/credit/CreditConfigurator.sol";
import {WstETHPoolSetup} from "./WstETHPoolSetup.sol";
import {OHMPoolSetup} from "./OHMPoolSetup.sol";

import {DegenNFT} from "@gearbox-protocol/core-v2/contracts/tokens/DegenNFT.sol";

import "../lib/constants.sol";

import {
    CreditConfigLive,
    CreditManagerHumanOpts,
    BalancerPool,
    UniswapV2Pair,
    UniswapV3Pool
} from "../config/CreditConfigLive.sol";
import {AdapterDeployer} from "./AdapterDeployer.sol";
import {Contracts, SupportedContracts} from "../config/SupportedContracts.sol";

address constant ADDRESS_PROVIDER = 0xcF64698AFF7E5f27A11dff868AF228653ba53be0;
address constant ADDRESS_PROVIDER_GOERLI = 0x95f4cea53121b8A2Cb783C6BFB0915cEc44827D3;

/// @title LiveEnvTestSuite
/// @notice Test suite for mainnet test
contract LiveEnvTestSuite is CreditConfigLive {
    using AddressList for address[];

    CheatCodes evm = CheatCodes(HEVM_ADDRESS);

    address public ROOT_ADDRESS;

    AddressProvider public addressProvider;
    ACL public acl;
    TokensTestSuite public tokenTestSuite;
    SupportedContracts public supportedContracts;
    PriceOracle public priceOracle;
    BlacklistHelper public blacklistHelper;

    Tokens[] supportedUnderlyings;

    mapping(Tokens => PoolService) public pools;

    mapping(Tokens => CreditManager[]) public _creditManagers;
    mapping(Tokens => CreditFacade[]) public _creditFacades;
    mapping(Tokens => CreditConfigurator[]) public _creditConfigurators;

    mapping(Tokens => CreditManagerLiveMock) public creditManagerMocks;
    mapping(Tokens => CreditFacade) public creditFacadeMocks;
    mapping(Tokens => CreditConfigurator) public creditConfiguratorMocks;

    CreditManager public activeCM;

    DegenNFT public degenNFT;

    constructor() CreditConfigLive() {
        if (block.chainid == 1337) {
            uint8 networkId;
            bool useExisting;

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

            address ap = networkId == 1 ? ADDRESS_PROVIDER : networkId == 2 ? ADDRESS_PROVIDER_GOERLI : address(0);

            supportedContracts = new SupportedContracts(networkId);
            addressProvider = AddressProvider(ap);
            acl = ACL(addressProvider.getACL());
            ROOT_ADDRESS = acl.owner();

            tokenTestSuite = new TokensTestSuite();

            if (useExisting) {
                priceOracle = PriceOracle(addressProvider.getPriceOracle());

                IDataCompressor dc = IDataCompressor(addressProvider.getDataCompressor());

                CreditManagerData[] memory cmList = dc.getCreditManagersList();

                bool mintedNFT = false;

                for (uint256 i = 0; i < cmList.length; ++i) {
                    if (cmList[i].version == 2) {
                        Tokens underlyingT = tokenTestSuite.tokenIndexes(cmList[i].underlying);

                        _creditManagers[underlyingT].push(CreditManager(cmList[i].addr));
                        _creditFacades[underlyingT].push(CreditFacade(cmList[i].creditFacade));
                        _creditConfigurators[underlyingT].push(CreditConfigurator(cmList[i].creditConfigurator));

                        string memory underlyingSymbol = tokenTestSuite.symbols(underlyingT);

                        if (CreditFacade(cmList[i].creditFacade).whitelisted() && !mintedNFT) {
                            DegenNFT dnft = DegenNFT(CreditFacade(cmList[i].creditFacade).degenNFT());

                            evm.prank(dnft.minter());
                            dnft.mint(USER, 30);
                            mintedNFT = true;
                        }

                        IPoolService pool = IPoolService(CreditManager(cmList[i].addr).pool());

                        if (address(pools[underlyingT]) == address(0)) {
                            pools[underlyingT] = PoolService(address(pool));
                            supportedUnderlyings.push(underlyingT);
                        }

                        uint256 expectedLiquidityUSD =
                            priceOracle.convertToUSD(pool.expectedLiquidity(), tokenTestSuite.addressOf(underlyingT));
                        uint256 oneMillionUSD = 1_000_000 * 10 ** 8;
                        if (expectedLiquidityUSD < oneMillionUSD) {
                            uint256 amountUSD = oneMillionUSD - expectedLiquidityUSD;
                            uint256 amount =
                                priceOracle.convertFromUSD(amountUSD, tokenTestSuite.addressOf(underlyingT));
                            tokenTestSuite.mint(underlyingT, FRIEND, amount);
                            tokenTestSuite.approve(underlyingT, FRIEND, address(pool));

                            evm.prank(FRIEND);
                            pool.addLiquidity(amount, FRIEND, 0);
                        }

                        evm.label(
                            cmList[i].creditFacade,
                            string(
                                abi.encodePacked(
                                    "CREDIT_FACADE_", underlyingSymbol, "_", _creditFacades[underlyingT].length
                                )
                            )
                        );
                        evm.label(
                            cmList[i].addr,
                            string(
                                abi.encodePacked(
                                    "CREDIT_MANAGER_", underlyingSymbol, "_", _creditManagers[underlyingT].length
                                )
                            )
                        );
                        evm.label(
                            cmList[i].creditConfigurator,
                            string(
                                abi.encodePacked(
                                    "CREDIT_CONFIGURATOR_",
                                    underlyingSymbol,
                                    "_",
                                    _creditConfigurators[underlyingT].length
                                )
                            )
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
                addressProvider.setPriceOracle(address(priceOracle)); // T:[GD-1]

                ContractsRegister cr = ContractsRegister(addressProvider.getContractsRegister());

                if (!_wstETHPoolExists(cr)) {
                    // SETUP wstETH pool if none is already deployed
                    new WstETHPoolSetup(
                        ap,
                        tokenTestSuite.addressOf(Tokens.wstETH),
                        tokenTestSuite,
                        ROOT_ADDRESS
                    );
                }

                if (!_OHMPoolExists(cr)) {
                    new OHMPoolSetup(
                        ap,
                        tokenTestSuite,
                        ROOT_ADDRESS
                    );
                }

                _setPools(cr);

                uint256 len = numOpts;
                unchecked {
                    for (uint256 i; i < len; ++i) {
                        Tokens underlyingT = creditManagerHumanOpts[i].underlying;

                        if (address(pools[underlyingT]) == address(0)) continue;
                        // REAL CREDIT MANAGERS
                        {
                            address underlying = tokenTestSuite.addressOf(underlyingT);

                            (CreditManagerOpts memory cmOpts, Contracts[] memory adaptersList) =
                                getCreditManagerConfig(i, false);

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
                                        "_",
                                        _creditManagers[underlyingT].length + 1,
                                        "_"
                                    )
                                ),
                                false
                            );
                            cmf.addAdapters(ad.getAdapters());

                            evm.prank(ROOT_ADDRESS);
                            acl.transferOwnership(address(cmf));
                            cmf.configure();

                            evm.label(
                                address(cmf.creditFacade()),
                                string(
                                    abi.encodePacked(
                                        "CREDIT_FACADE_", underlyingSymbol, "_", _creditFacades[underlyingT].length + 1
                                    )
                                )
                            );
                            evm.label(
                                address(cmf.creditManager()),
                                string(
                                    abi.encodePacked(
                                        "CREDIT_MANAGER_", underlyingSymbol, "_", _creditFacades[underlyingT].length + 1
                                    )
                                )
                            );
                            evm.label(
                                address(cmf.creditConfigurator()),
                                string(
                                    abi.encodePacked(
                                        "CREDIT_CONFIGURATOR_",
                                        underlyingSymbol,
                                        "_",
                                        _creditFacades[underlyingT].length + 1
                                    )
                                )
                            );

                            _creditManagers[underlyingT].push(cmf.creditManager());
                            _creditFacades[underlyingT].push(cmf.creditFacade());
                            _creditConfigurators[underlyingT].push(cmf.creditConfigurator());

                            evm.startPrank(ROOT_ADDRESS);
                            if (cmf.creditFacade().isBlacklistableUnderlying()) {
                                blacklistHelper.addCreditFacade(address(cmf.creditFacade()));
                            }
                            evm.stopPrank();

                            _configureUniswapV2Pairs(address(cmf.creditManager()), i);
                            _configureUniswapV3Pools(address(cmf.creditManager()), i);
                            _configureConvexPhantomTokens(address(cmf.creditManager()));
                            _configureBalancerPools(address(cmf.creditManager()), i);
                        }

                        // MOCK CREDIT MANAGERS
                        // Mock credit managers skip health checks
                        if (underlyingT == Tokens.DAI || underlyingT == Tokens.wstETH) {
                            address underlying = tokenTestSuite.addressOf(underlyingT);

                            (CreditManagerOpts memory cmOpts, Contracts[] memory adaptersList) =
                                getCreditManagerConfig(i, true);

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
                                ),
                                true
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

                            _configureUniswapV2Pairs(address(cmf.creditManager()), i);
                            _configureUniswapV3Pools(address(cmf.creditManager()), i);
                            _configureConvexPhantomTokens(address(cmf.creditManager()));
                            _configureBalancerPools(address(cmf.creditManager()), i);
                        }
                    }
                }
            }

            string memory testedSymbol;
            uint256 testedIndex;

            try evm.envString("ETH_FORK_TESTED_CM_ASSET") returns (string memory asset) {
                testedSymbol = asset;
            } catch {
                testedSymbol = "DAI";
            }

            try evm.envInt("ETH_FORK_TESTED_CM_INDEX") returns (int256 idx) {
                testedIndex = uint256(idx);
            } catch {
                testedIndex = 0;
            }

            Tokens testedAsset = tokenTestSuite.symbolToAsset(testedSymbol);
            activeCM = _creditManagers[testedAsset][testedIndex];

            uint256 accountAmount;
            {
                (uint128 minAmount, uint128 maxAmount) = _creditFacades[testedAsset][testedIndex].limits();

                accountAmount = uint256(minAmount + maxAmount) / 2;
            }

            IPoolService pool = IPoolService(activeCM.pool());

            if (pool.availableLiquidity() < accountAmount) {
                tokenTestSuite.mint(activeCM.underlying(), FRIEND, accountAmount);
                tokenTestSuite.approve(activeCM.underlying(), FRIEND, address(pool));

                evm.prank(FRIEND);
                pool.addLiquidity(accountAmount, FRIEND, 0);
            }
        }
    }

    function _wstETHPoolExists(ContractsRegister cr) internal view returns (bool) {
        address[] memory pools = cr.getPools();

        for (uint256 i = 0; i < pools.length; ++i) {
            if (IPoolService(pools[i]).underlyingToken() == tokenTestSuite.addressOf(Tokens.wstETH)) {
                return true;
            }
        }

        return false;
    }

    function _OHMPoolExists(ContractsRegister cr) internal view returns (bool) {
        address[] memory pools = cr.getPools();

        for (uint256 i = 0; i < pools.length; ++i) {
            if (IPoolService(pools[i]).underlyingToken() == tokenTestSuite.addressOf(Tokens.OHM)) {
                return true;
            }
        }

        return false;
    }

    function _configureConvexPhantomTokens(address creditManager) internal {
        address boosterAdapter = getAdapter(creditManager, Contracts.CONVEX_BOOSTER);

        evm.prank(ROOT_ADDRESS);
        IConvexV1BoosterAdapter(boosterAdapter).updateStakedPhantomTokensMap();
    }

    function _configureBalancerPools(address creditManager, uint256 configIdx) internal {
        BalancerPool[] memory bPools = creditManagerHumanOpts[configIdx].balancerPools;

        if (bPools.length == 0) return;

        address balancerAdapter = getAdapter(creditManager, Contracts.BALANCER_VAULT);

        for (uint256 i = 0; i < bPools.length; ++i) {
            evm.prank(ROOT_ADDRESS);
            BalancerV2VaultAdapter(balancerAdapter).setPoolIDStatus(bPools[i].poolId, bPools[i].status);
        }
    }

    function _configureUniswapV2Pairs(address creditManager, uint256 configIdx) internal {
        UniswapV2Pair[] memory uniV2Pairs = creditManagerHumanOpts[configIdx].uniswapV2Pairs;

        if (uniV2Pairs.length == 0) return;

        UniswapPairStatus[] memory pairs = new UniswapPairStatus[](uniV2Pairs.length);

        for (uint256 i = 0; i < uniV2Pairs.length; ++i) {
            pairs[i] = UniswapPairStatus({
                token0: tokenTestSuite.addressOf(uniV2Pairs[i].token0),
                token1: tokenTestSuite.addressOf(uniV2Pairs[i].token1),
                allowed: true
            });
        }

        address uniV2Adapter = getAdapter(creditManager, Contracts.UNISWAP_V2_ROUTER);

        evm.prank(ROOT_ADDRESS);
        UniswapV2Adapter(uniV2Adapter).setPairBatchAllowanceStatus(pairs);
    }

    function _configureUniswapV3Pools(address creditManager, uint256 configIdx) internal {
        UniswapV3Pool[] memory uniV3Pools = creditManagerHumanOpts[configIdx].uniswapV3Pools;

        if (uniV3Pools.length == 0) return;

        UniswapV3PoolStatus[] memory pools = new UniswapV3PoolStatus[](uniV3Pools.length);

        for (uint256 i = 0; i < uniV3Pools.length; ++i) {
            pools[i] = UniswapV3PoolStatus({
                token0: tokenTestSuite.addressOf(uniV3Pools[i].token0),
                token1: tokenTestSuite.addressOf(uniV3Pools[i].token1),
                fee: uniV3Pools[i].fee,
                allowed: true
            });
        }

        address uniV3Adapter = getAdapter(creditManager, Contracts.UNISWAP_V3_ROUTER);

        evm.prank(ROOT_ADDRESS);
        UniswapV3Adapter(uniV3Adapter).setPoolBatchAllowanceStatus(pools);
    }

    function _setPools(ContractsRegister cr) internal {
        address[] memory poolsList = cr.getPools();
        uint256 len = poolsList.length;

        for (uint256 i = 0; i < len; ++i) {
            address poolUnderlying = IPoolService(poolsList[i]).underlyingToken();

            Tokens underlyingT = tokenTestSuite.tokenIndexes(poolUnderlying);
            string memory underlyingSymbol = tokenTestSuite.symbols(underlyingT);

            pools[underlyingT] = PoolService(poolsList[i]);
            supportedUnderlyings.push(underlyingT);
            evm.label(poolsList[i], string(abi.encodePacked("POOL_", underlyingSymbol)));

            {
                IPoolService pool = pools[underlyingT];

                uint256 expectedLiquidityUSD =
                    priceOracle.convertToUSD(pool.expectedLiquidity(), tokenTestSuite.addressOf(underlyingT));
                uint256 oneMillionUSD = 1_000_000 * 10 ** 8;
                if (expectedLiquidityUSD < oneMillionUSD) {
                    uint256 amountUSD = oneMillionUSD - expectedLiquidityUSD;
                    uint256 amount = priceOracle.convertFromUSD(amountUSD, tokenTestSuite.addressOf(underlyingT));
                    tokenTestSuite.mint(underlyingT, FRIEND, amount);
                    tokenTestSuite.approve(underlyingT, FRIEND, address(pool));

                    evm.prank(FRIEND);
                    pool.addLiquidity(amount, FRIEND, 0);
                }
            }
        }
    }

    function getCreditManagerConfig(uint256 idx, bool isMock)
        internal
        view
        returns (CreditManagerOpts memory cmOpts, Contracts[] memory adaptersList)
    {
        CreditManagerHumanOpts memory humanCfg = creditManagerHumanOpts[idx];

        if (isMock) {
            address[] memory allTokens = new address[](uint256(uint8(type(Tokens).max)));

            uint256 j;

            for (uint256 i = 0; i < allTokens.length; ++i) {
                address token = tokenTestSuite.addressOf(Tokens(uint8(i)));

                try priceOracle.priceFeeds(token) returns (address pf) {}
                catch {
                    continue;
                }

                if (token == address(0) || humanCfg.underlying == Tokens(uint8(i))) continue;

                allTokens[j] = token;
                ++j;
            }

            allTokens = allTokens.trim();

            cmOpts.collateralTokens = new CollateralToken[](allTokens.length);
            for (uint256 i; i < allTokens.length; ++i) {
                cmOpts.collateralTokens[i] = CollateralToken({token: allTokens[i], liquidationThreshold: 9000});
            }
        } else {
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
        }

        cmOpts.minBorrowedAmount = humanCfg.minBorrowedAmount;
        cmOpts.maxBorrowedAmount = humanCfg.maxBorrowedAmount;
        cmOpts.degenNFT = humanCfg.degenNFT;
        cmOpts.expirable = humanCfg.expirable;
        if (isMock) {
            adaptersList = new Contracts[](uint256(uint8(type(Contracts).max)));
            for (uint256 i; i < adaptersList.length; ++i) {
                adaptersList[i] = Contracts(uint8(i));
            }
        } else {
            adaptersList = humanCfg.contracts;
        }
    }

    function getAdapter(Tokens underlying, Contracts target) public view returns (address) {
        return _creditManagers[underlying][0].contractToAdapter(supportedContracts.addressOf(target));
    }

    function getAdapter(address creditManager, Contracts target) public view returns (address) {
        return CreditManager(creditManager).contractToAdapter(supportedContracts.addressOf(target));
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

    function getActiveCM()
        public
        view
        returns (CreditManager cm, CreditFacade cf, CreditConfigurator cc, uint256 accountAmount)
    {
        cm = activeCM;
        cf = CreditFacade(cm.creditFacade());
        cc = CreditConfigurator(cm.creditConfigurator());

        (uint128 minBorrowAmount, uint128 maxBorrowAmount) = cf.limits();

        accountAmount = uint256(minBorrowAmount + maxBorrowAmount) / 2;
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

    function getSupportedUnderlyings() public view returns (Tokens[] memory) {
        return supportedUnderlyings;
    }
}
