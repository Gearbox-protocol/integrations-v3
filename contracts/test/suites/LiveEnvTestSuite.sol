// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2023
pragma solidity ^0.8.17;

import {Tokens} from "../config/Tokens.sol";
import {TokensTestSuite} from "./TokensTestSuite.sol";
import {LivePriceFeedDeployer} from "./LivePriceFeedDeployer.sol";
import {IDataCompressor} from "@gearbox-protocol/core-v2/contracts/interfaces/IDataCompressor.sol";
import {CreditManagerData} from "@gearbox-protocol/core-v2/contracts/libraries/Types.sol";

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
import {BlacklistHelper} from "@gearbox-protocol/core-v2/contracts/support/BlacklistHelper.sol";
import {PoolService} from "@gearbox-protocol/core-v2/contracts/pool/PoolService.sol";

import {CreditManagerFactory} from "../../factories/CreditManagerFactory.sol";
import {CreditManagerMockFactory} from "../mocks/credit/CreditManagerMockFactory.sol";
import {CreditManagerOpts, CollateralToken} from "@gearbox-protocol/core-v2/contracts/credit/CreditConfigurator.sol";
import {WstETHPoolSetup} from "./WstETHPoolSetup.sol";
import {OHMPoolSetup} from "./OHMPoolSetup.sol";

import {DegenNFT} from "@gearbox-protocol/core-v2/contracts/tokens/DegenNFT.sol";

import "../lib/constants.sol";

import {CreditConfigLive, CreditManagerHumanOpts, BalancerPool} from "../config/CreditConfigLive.sol";
import {AdapterDeployer} from "./AdapterDeployer.sol";
import {Contracts, SupportedContracts} from "../config/SupportedContracts.sol";

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

                        pools[underlyingT] = PoolService(address(pool));
                        supportedUnderlyings.push(underlyingT);

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
                                        "_",
                                        _creditManagers[underlyingT].length + 1,
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

                            _configureConvexPhantomTokens(address(cmf.creditManager()));
                            _configureBalancerPools(address(cmf.creditManager()), i);
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
        }
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
