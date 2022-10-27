// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import { Tokens } from "../config/Tokens.sol";
import { TokensTestSuite } from "./TokensTestSuite.sol";
import { LivePriceFeedDeployer } from "./LivePriceFeedDeployer.sol";
import { IDataCompressor } from "@gearbox-protocol/core-v2/contracts/interfaces/IDataCompressor.sol";
import { CreditManagerData } from "@gearbox-protocol/core-v2/contracts/libraries/Types.sol";

import { AddressProvider } from "@gearbox-protocol/core-v2/contracts/core/AddressProvider.sol";

import { ACL } from "@gearbox-protocol/core-v2/contracts/core/ACL.sol";
import { ContractsRegister } from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";
import { PriceOracle } from "@gearbox-protocol/core-v2/contracts/oracles/PriceOracle.sol";
import { IPoolService } from "@gearbox-protocol/core-v2/contracts/interfaces/IPoolService.sol";

import { CreditFacade } from "@gearbox-protocol/core-v2/contracts/credit/CreditFacade.sol";
import { CreditConfigurator } from "@gearbox-protocol/core-v2/contracts/credit/CreditConfigurator.sol";
import { CreditManager } from "@gearbox-protocol/core-v2/contracts/credit/CreditManager.sol";
import { CreditManagerLiveMock } from "../mocks/credit/CreditManagerLiveMock.sol";
import { Balance } from "@gearbox-protocol/core-v2/contracts/libraries/Balances.sol";

import { CreditManagerFactory } from "../../factories/CreditManagerFactory.sol";
import { CreditManagerMockFactory } from "../mocks/credit/CreditManagerMockFactory.sol";
import { CreditManagerOpts, CollateralToken } from "@gearbox-protocol/core-v2/contracts/credit/CreditConfigurator.sol";
import { WstETHPoolSetup } from "./WstETHPoolSetup.sol";

import { DegenNFT } from "@gearbox-protocol/core-v2/contracts/tokens/DegenNFT.sol";

import "../lib/constants.sol";

import { CreditConfigLive, CreditManagerHumanOpts } from "../config/CreditConfigLive.sol";
import { AdapterDeployer } from "./AdapterDeployer.sol";
import { Contracts, SupportedContracts } from "../config/SupportedContracts.sol";

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

    mapping(Tokens => CreditManager) public creditManagers;
    mapping(Tokens => CreditFacade) public creditFacades;
    mapping(Tokens => CreditConfigurator) public creditConfigurators;

    mapping(Tokens => CreditManagerLiveMock) public creditManagerMocks;
    mapping(Tokens => CreditFacade) public creditFacadeMocks;
    mapping(Tokens => CreditConfigurator) public creditConfiguratorMocks;

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

            address ap = networkId == 1 ? ADDRESS_PROVIDER : networkId == 2
                ? ADDRESS_PROVIDER_GOERLI
                : address(0);

            supportedContracts = new SupportedContracts(networkId);
            addressProvider = AddressProvider(ap);
            acl = ACL(addressProvider.getACL());
            ROOT_ADDRESS = acl.owner();

            tokenTestSuite = new TokensTestSuite();

            if (useExisting) {
                priceOracle = PriceOracle(addressProvider.getPriceOracle());

                IDataCompressor dc = IDataCompressor(
                    addressProvider.getDataCompressor()
                );

                CreditManagerData[] memory cmList = dc.getCreditManagersList();

                bool mintedNFT = false;

                for (uint256 i = 0; i < cmList.length; ++i) {
                    if (cmList[i].version == 2) {
                        Tokens underlyingT = tokenTestSuite.tokenIndexes(
                            cmList[i].underlying
                        );

                        creditManagers[underlyingT] = CreditManager(
                            cmList[i].addr
                        );
                        creditFacades[underlyingT] = CreditFacade(
                            cmList[i].creditFacade
                        );
                        creditConfigurators[underlyingT] = CreditConfigurator(
                            cmList[i].creditConfigurator
                        );

                        string memory underlyingSymbol = tokenTestSuite.symbols(
                            underlyingT
                        );

                        if (
                            creditFacades[underlyingT].whitelisted() &&
                            !mintedNFT
                        ) {
                            DegenNFT dnft = DegenNFT(
                                creditFacades[underlyingT].degenNFT()
                            );

                            evm.prank(dnft.minter());
                            dnft.mint(USER, 30);
                            mintedNFT = true;
                        }

                        evm.label(
                            cmList[i].creditFacade,
                            string(
                                abi.encodePacked(
                                    "CREDIT_FACADE_",
                                    underlyingSymbol
                                )
                            )
                        );
                        evm.label(
                            cmList[i].addr,
                            string(
                                abi.encodePacked(
                                    "CREDIT_MANAGER_",
                                    underlyingSymbol
                                )
                            )
                        );
                        evm.label(
                            cmList[i].creditConfigurator,
                            string(
                                abi.encodePacked(
                                    "CREDIT_CONFIGURATOR_",
                                    underlyingSymbol
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

                evm.prank(ROOT_ADDRESS);
                addressProvider.setPriceOracle(address(priceOracle)); // T:[GD-1]

                ContractsRegister cr = ContractsRegister(
                    addressProvider.getContractsRegister()
                );

                if (!_wstETHPoolExists(cr)) {
                    // SETUP wstETH pool if none is already deployed
                    new WstETHPoolSetup(
                        ap,
                        tokenTestSuite.addressOf(Tokens.wstETH),
                        tokenTestSuite,
                        ROOT_ADDRESS
                    );
                }

                address[] memory pools = cr.getPools();
                uint256 len = pools.length;
                unchecked {
                    for (uint256 i; i < len; ++i) {
                        // REAL CREDIT MANAGERS
                        {
                            address underlying = IPoolService(pools[i])
                                .underlyingToken();

                            (
                                bool found,
                                CreditManagerOpts memory cmOpts,
                                Contracts[] memory adaptersList
                            ) = getCreditManagerConfig(underlying);

                            if (!found) continue;

                            CreditManagerFactory cmf = new CreditManagerFactory(
                                pools[i],
                                cmOpts,
                                0
                            );

                            Tokens underlyingT = tokenTestSuite.tokenIndexes(
                                underlying
                            );

                            string memory underlyingSymbol = tokenTestSuite
                                .symbols(underlyingT);

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

                            evm.label(
                                pools[i],
                                string(
                                    abi.encodePacked("POOL_", underlyingSymbol)
                                )
                            );
                            evm.label(
                                address(cmf.creditFacade()),
                                string(
                                    abi.encodePacked(
                                        "CREDIT_FACADE_",
                                        underlyingSymbol
                                    )
                                )
                            );
                            evm.label(
                                address(cmf.creditManager()),
                                string(
                                    abi.encodePacked(
                                        "CREDIT_MANAGER_",
                                        underlyingSymbol
                                    )
                                )
                            );
                            evm.label(
                                address(cmf.creditConfigurator()),
                                string(
                                    abi.encodePacked(
                                        "CREDIT_CONFIGURATOR_",
                                        underlyingSymbol
                                    )
                                )
                            );

                            creditManagers[underlyingT] = cmf.creditManager();
                            creditFacades[underlyingT] = cmf.creditFacade();
                            creditConfigurators[underlyingT] = cmf
                                .creditConfigurator();
                        }

                        // MOCK CREDIT MANAGERS
                        // Mock credit managers skip health checks
                        {
                            address underlying = IPoolService(pools[i])
                                .underlyingToken();

                            (
                                bool found,
                                CreditManagerOpts memory cmOpts,
                                Contracts[] memory adaptersList
                            ) = getCreditManagerConfig(underlying);

                            if (!found) continue;

                            CreditManagerMockFactory cmf = new CreditManagerMockFactory(
                                    pools[i],
                                    cmOpts,
                                    0
                                );

                            Tokens underlyingT = tokenTestSuite.tokenIndexes(
                                underlying
                            );

                            string memory underlyingSymbol = tokenTestSuite
                                .symbols(underlyingT);

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
                                string(
                                    abi.encodePacked(
                                        "CREDIT_FACADE_MOCK_",
                                        underlyingSymbol
                                    )
                                )
                            );
                            evm.label(
                                address(cmf.creditManager()),
                                string(
                                    abi.encodePacked(
                                        "CREDIT_MANAGER_MOCK_",
                                        underlyingSymbol
                                    )
                                )
                            );
                            evm.label(
                                address(cmf.creditConfigurator()),
                                string(
                                    abi.encodePacked(
                                        "CREDIT_CONFIGURATOR_MOCK_",
                                        underlyingSymbol
                                    )
                                )
                            );

                            creditManagerMocks[underlyingT] = cmf
                                .creditManager();
                            creditFacadeMocks[underlyingT] = cmf.creditFacade();
                            creditConfiguratorMocks[underlyingT] = cmf
                                .creditConfigurator();
                        }
                    }
                }
            }
        }

        // // Charge USER
        // tokenTestSuite.mint(_underlying, USER, _getAccountAmount());
        // tokenTestSuite.mint(_underlying, FRIEND, _getAccountAmount());
        // evm.prank(USER);
        // IERC20(underlying).approve(address(creditManager), type(uint256).max);
        // evm.prank(FRIEND);
        // IERC20(underlying).approve(address(creditManager), type(uint256).max);

        // addressProvider.transferOwnership(CONFIGURATOR);
        // acl.transferOwnership(CONFIGURATOR);

        // evm.startPrank(CONFIGURATOR);

        // acl.claimOwnership();
        // addressProvider.claimOwnership();

        // evm.stopPrank();
    }

    function _wstETHPoolExists(ContractsRegister cr) internal returns (bool) {
        address[] memory pools = cr.getPools();

        for (uint256 i = 0; i < pools.length; ++i) {
            if (
                IPoolService(pools[i]).underlyingToken() ==
                tokenTestSuite.addressOf(Tokens.wstETH)
            ) {
                return true;
            }
        }

        return false;
    }

    // function testFacadeWithDegenNFT() external {
    //   degenNFT = new DegenNFT(address(addressProvider), "DegenNFT", "Gear-Degen");

    //   evm.startPrank(CONFIGURATOR);

    //   degenNFT.setMinter(CONFIGURATOR);

    //   creditFacade = new CreditFacade(
    //     address(creditManager),
    //     address(degenNFT),
    //     false
    //   );

    //   creditConfigurator.upgradeCreditFacade(address(creditFacade), true);

    //   degenNFT.addCreditFacade(address(creditFacade));

    //   evm.stopPrank();
    // }

    // function testFacadeWithExpiration() external {
    //   evm.startPrank(CONFIGURATOR);

    //   creditFacade = new CreditFacade(address(creditManager), address(0), true);

    //   creditConfigurator.upgradeCreditFacade(address(creditFacade), true);
    //   creditConfigurator.setExpirationDate(uint40(block.timestamp + 1));

    //   evm.stopPrank();
    // }

    function getCreditManagerConfig(address poolUnderlying)
        internal
        view
        returns (
            bool found,
            CreditManagerOpts memory cmOpts,
            Contracts[] memory adaptersList
        )
    {
        Tokens index = tokenTestSuite.tokenIndexes(poolUnderlying);
        if (index == Tokens.NO_TOKEN) {
            return (false, cmOpts, adaptersList);
        } else {
            found = true;
        }

        CreditManagerHumanOpts memory humanCfg = creditManagerHumanOpts[index];

        uint256 len = humanCfg.collateralTokens.length;

        cmOpts.collateralTokens = new CollateralToken[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                cmOpts.collateralTokens[i] = CollateralToken({
                    token: tokenTestSuite.addressOf(
                        humanCfg.collateralTokens[i].token
                    ),
                    liquidationThreshold: humanCfg
                        .collateralTokens[i]
                        .liquidationThreshold
                });
            }
        }
        cmOpts.minBorrowedAmount = humanCfg.minBorrowedAmount;
        cmOpts.maxBorrowedAmount = humanCfg.maxBorrowedAmount;
        cmOpts.degenNFT = humanCfg.degenNFT;
        cmOpts.expirable = humanCfg.expirable;
        adaptersList = humanCfg.contracts;
    }

    function getAdapter(Tokens underlying, Contracts target)
        public
        view
        returns (address)
    {
        return
            creditManagers[underlying].contractToAdapter(
                supportedContracts.addressOf(target)
            );
    }

    function getMockAdapter(Tokens underlying, Contracts target)
        public
        view
        returns (address)
    {
        return
            creditManagerMocks[underlying].contractToAdapter(
                supportedContracts.addressOf(target)
            );
    }

    function getAdapters(Tokens underlying)
        public
        view
        returns (address[] memory adapters)
    {
        uint256 contractCount = supportedContracts.contractCount();

        adapters = new address[](contractCount);

        for (uint256 i = 0; i < contractCount; ++i) {
            adapters[i] = getAdapter(underlying, Contracts(i));
        }
    }

    function getBalances() public view returns (Balance[] memory balances) {
        uint256 tokenCount = uint256(type(Tokens).max);

        balances = new Balance[](tokenCount);

        for (uint256 i = 0; i < tokenCount; ++i) {
            balances[i].token = tokenTestSuite.addressOf(Tokens(i));
        }
    }
}
