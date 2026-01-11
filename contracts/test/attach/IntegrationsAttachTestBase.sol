// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ICreditFacadeV3, MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";

import {ConstantPriceFeed} from "@gearbox-protocol/oracles-v3/contracts/oracles/ConstantPriceFeed.sol";

import {AttachTestBase} from "@gearbox-protocol/permissionless/contracts/test/suite/AttachTestBase.sol";

abstract contract IntegrationsAttachTestBase is AttachTestBase {
    address zeroPriceFeed;
    address onePriceFeed;

    address underlying;
    address pool;
    address creditManager;
    address creditFacade;

    address user;
    address creditAccount;

    function _setUp() internal {
        // NOTE: even though we compile our contracts under Shanghai EVM version,
        // more recent one might be needed to interact with third-party contracts
        vm.setEvmVersion("osaka");

        _attachCore();

        zeroPriceFeed = priceFeedStore.zeroPriceFeed();
        if (bytecodeRepository.getAllowedBytecodeHash("PRICE_FEED::CONSTANT", 3_10) == 0) {
            // NOTE: this would fail on deployment if we bump `ConstantPriceFeed` to v3.1.1 in the oracles repo,
            // but we assume that in this case v3.1.0 would already be uploaded to the bytecode repository
            _uploadContract("PRICE_FEED::CONSTANT", 3_10, type(ConstantPriceFeed).creationCode);
        }
        onePriceFeed = _deploy("PRICE_FEED::CONSTANT", 3_10, abi.encode(1e8, "$1 price feed"));
        _addPriceFeed(onePriceFeed, 0, "$1 price feed");

        _attachMarketConfigurator();

        underlying = address(new ERC20("Mock Token", "MOCK"));
        _allowPriceFeed(underlying, onePriceFeed);
        pool = _createMockMarket(underlying, onePriceFeed);
        creditManager = _createMockCreditSuite({pool: pool, minDebt: 1e18, maxDebt: 1e18, debtLimit: 0});
        creditFacade = ICreditManagerV3(creditManager).creditFacade();

        user = makeAddr("user");
        creditAccount = ICreditFacadeV3(creditFacade).openCreditAccount(user, new MultiCall[](0), 0);
    }

    // ----------------------- //
    // CONFIGURATION FUNCTIONS //
    // ----------------------- //

    function _addToken(address token) internal {
        _allowPriceFeed(token, zeroPriceFeed);
        _addToken(
            pool,
            TokenConfig({
                token: token, priceFeed: zeroPriceFeed, reservePriceFeed: address(0), quotaLimit: 0, quotaRate: 0
            })
        );
        _addCollateralToken(creditManager, token, 0);
    }

    function _getAdapterFor(address targetContract) internal view returns (address) {
        return ICreditManagerV3(creditManager).contractToAdapter(targetContract);
    }

    // -------------- //
    // USER FUNCTIONS //
    // -------------- //

    function _multicall(MultiCall[] memory calls) internal {
        vm.prank(user);
        ICreditFacadeV3(creditFacade).multicall(creditAccount, calls);
    }

    function _multicall(MultiCall memory call0) internal {
        MultiCall[] memory calls = new MultiCall[](1);
        calls[0] = call0;
        _multicall(calls);
    }

    function _multicall(MultiCall memory call0, MultiCall memory call1) internal {
        MultiCall[] memory calls = new MultiCall[](2);
        calls[0] = call0;
        calls[1] = call1;
        _multicall(calls);
    }

    function _multicall(MultiCall memory call0, MultiCall memory call1, MultiCall memory call2) internal {
        MultiCall[] memory calls = new MultiCall[](3);
        calls[0] = call0;
        calls[1] = call1;
        calls[2] = call2;
        _multicall(calls);
    }

    function _multicall(MultiCall memory call0, MultiCall memory call1, MultiCall memory call2, MultiCall memory call3)
        internal
    {
        MultiCall[] memory calls = new MultiCall[](4);
        calls[0] = call0;
        calls[1] = call1;
        calls[2] = call2;
        calls[3] = call3;
        _multicall(calls);
    }

    function _multicall(
        MultiCall memory call0,
        MultiCall memory call1,
        MultiCall memory call2,
        MultiCall memory call3,
        MultiCall memory call4
    ) internal {
        MultiCall[] memory calls = new MultiCall[](5);
        calls[0] = call0;
        calls[1] = call1;
        calls[2] = call2;
        calls[3] = call3;
        calls[4] = call4;
        _multicall(calls);
    }
}
