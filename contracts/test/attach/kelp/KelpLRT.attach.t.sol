// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";

import {KelpLRTDepositPoolAdapter} from "../../../adapters/kelp/KelpLRTDepositPoolAdapter.sol";
import {
    KelpLRTWithdrawalManagerAdapter,
    TokenOutStatus
} from "../../../adapters/kelp/KelpLRTWithdrawalManagerAdapter.sol";
import {KelpLRTDepositPoolGateway} from "../../../helpers/kelp/KelpLRTDepositPoolGateway.sol";
import {KelpLRTWithdrawalManagerGateway} from "../../../helpers/kelp/KelpLRTWithdrawalManagerGateway.sol";
import {KelpLRTWithdrawalPhantomToken} from "../../../helpers/kelp/KelpLRTWithdrawalPhantomToken.sol";

import {IntegrationsAttachTestBase} from "../IntegrationsAttachTestBase.sol";

contract KelpLRTAttachTest is IntegrationsAttachTestBase {
    address constant rsETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address constant DEPOSIT_POOL = 0x036676389e48133B63a802f8635AD39E752D375D;
    address constant WITHDRAWAL_MANAGER = 0x62De59c08eB5dAE4b7E6F7a8cAd3006d6965ec16;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant ETHx = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;

    address depositPoolGateway;
    address withdrawalManagerGateway;

    address[3] tokens = [WETH, stETH, ETHx];
    mapping(address token => address) withdrawalTokens;

    function setUp() public {
        super._setUp();

        vm.skip(block.chainid != 1, "Not Ethereum mainnet");

        _uploadContract("ADAPTER::KELP_DEPOSIT_POOL", 3_10, type(KelpLRTDepositPoolAdapter).creationCode);
        _uploadContract("ADAPTER::KELP_WITHDRAWAL", 3_10, type(KelpLRTWithdrawalManagerAdapter).creationCode);
        _uploadContract("GATEWAY::KELP_DEPOSIT_POOL", 3_10, type(KelpLRTDepositPoolGateway).creationCode);
        _uploadContract("GATEWAY::KELP_WITHDRAWAL", 3_10, type(KelpLRTWithdrawalManagerGateway).creationCode);
        _uploadContract("PHANTOM_TOKEN::KELP_WITHDRAWAL", 3_10, type(KelpLRTWithdrawalPhantomToken).creationCode);

        depositPoolGateway = _deploy("GATEWAY::KELP_DEPOSIT_POOL", 3_10, abi.encode(WETH, DEPOSIT_POOL));
        withdrawalManagerGateway =
            _deploy("GATEWAY::KELP_WITHDRAWAL", 3_10, abi.encode(WITHDRAWAL_MANAGER, rsETH, WETH));

        _addToken(rsETH);
        _allowAdapter(
            creditManager, "KELP_DEPOSIT_POOL", abi.encode(creditManager, depositPoolGateway, "Gearbox Referral")
        );
        _allowAdapter(
            creditManager, "KELP_WITHDRAWAL", abi.encode(creditManager, withdrawalManagerGateway, "Gearbox Referral")
        );

        for (uint256 i; i < tokens.length; ++i) {
            address token = tokens[i];
            withdrawalTokens[token] =
                _deploy("PHANTOM_TOKEN::KELP_WITHDRAWAL", 3_10, abi.encode(withdrawalManagerGateway, token));

            _addToken(token);
            _addToken(withdrawalTokens[token]);

            address[] memory assets = new address[](1);
            bool[] memory allowed = new bool[](1);
            assets[0] = token;
            allowed[0] = true;
            _configureAdapter(
                creditManager,
                depositPoolGateway,
                abi.encodeCall(KelpLRTDepositPoolAdapter.setAssetStatusBatch, (assets, allowed))
            );

            TokenOutStatus[] memory tokensOut = new TokenOutStatus[](1);
            tokensOut[0] = TokenOutStatus(token, withdrawalTokens[token], true);
            _configureAdapter(
                creditManager,
                withdrawalManagerGateway,
                abi.encodeCall(KelpLRTWithdrawalManagerAdapter.setTokensOutBatchStatus, (tokensOut))
            );
        }
    }

    function test_kelp_lrt_deposits_with_native_token(uint256 amount) public {
        amount = bound(amount, 0.001 ether, 1000 ether);
        address token = WETH;

        _deal_WETH(creditAccount, amount);

        _multicall(
            MultiCall(
                _getAdapterFor(depositPoolGateway),
                abi.encodeCall(KelpLRTDepositPoolAdapter.depositAsset, (token, amount, 0, ""))
            )
        );
    }

    function test_kelp_lrt_deposits_with_rebalancing_token(uint256 amount) public {
        amount = bound(amount, 0.001 ether, 1000 ether);
        address token = stETH;

        _deal_stETH(creditAccount, amount);

        _multicall(
            MultiCall(
                _getAdapterFor(depositPoolGateway),
                abi.encodeCall(KelpLRTDepositPoolAdapter.depositAsset, (token, amount, 0, ""))
            )
        );
    }

    function test_kelp_lrt_deposits_with_erc20_token(uint256 amount) public {
        amount = bound(amount, 0.001 ether, 1000 ether);
        address token = ETHx;

        deal(token, creditAccount, amount, true);

        _multicall(
            MultiCall(
                _getAdapterFor(depositPoolGateway),
                abi.encodeCall(KelpLRTDepositPoolAdapter.depositAsset, (token, amount, 0, ""))
            )
        );
    }

    function _deal_WETH(address to, uint256 amount) internal {
        deal(address(this), amount);
        (bool success,) = address(WETH).call{value: amount}("");
        require(success, "WETH deposit failed");
        ERC20(WETH).transfer(to, amount);
    }

    function _deal_stETH(address to, uint256 amount) internal {
        deal(address(this), amount);
        (bool success,) = address(stETH).call{value: amount}("");
        require(success, "stETH deposit failed");
        // TODO: might be imprecise
        ERC20(stETH).transfer(to, amount);
    }
}
