// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {LidoMock} from "../mocks/integrations/LidoMock.sol";

import {TokenType} from "../../integrations/TokenType.sol";
import {IWETH} from "@gearbox-protocol/core-v2/contracts/interfaces/external/IWETH.sol";

// MOCKS
import {Tokens} from "../config/Tokens.sol";
import {ERC20Mock} from "@gearbox-protocol/core-v2/contracts/test/mocks/token/ERC20Mock.sol";
import {cERC20Mock} from "../mocks/token/cERC20Mock.sol";

import "@gearbox-protocol/core-v2/contracts/test/lib/test.sol";
import {TokensData, TestToken} from "../config/TokensData.sol";
import {TokensDataLive} from "../config/TokensDataLive.sol";
import {TokensTestSuiteHelper} from "@gearbox-protocol/core-v2/contracts/test/suites/TokensTestSuiteHelper.sol";
import {IstETH} from "../../integrations/lido/IstETH.sol";

import "../lib/constants.sol";

struct TokenData {
    Tokens id;
    address addr;
    string symbol;
    TokenType tokenType;
}

address constant LDO_DONOR = 0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c;

contract TokensTestSuite is DSTest, TokensTestSuiteHelper {
    using SafeERC20 for IERC20;

    mapping(Tokens => address) public addressOf;
    mapping(Tokens => TokenType) public tokenTypes;

    mapping(Tokens => string) public symbols;
    mapping(Tokens => uint256) public prices;
    mapping(string => Tokens) public symbolToAsset;

    mapping(address => Tokens) public tokenIndexes;

    uint256 public tokenCount;

    bool public mockTokens;

    constructor() {
        TokenData[] memory td;

        if (block.chainid == 1337) {
            uint8 networkId;

            try evm.envInt("ETH_FORK_NETWORK_ID") returns (int256 val) {
                networkId = uint8(uint256(val));
            } catch {
                networkId = 1;
            }

            TokensDataLive tdd = new TokensDataLive(networkId);
            td = tdd.getTokenData();
            mockTokens = false;
        } else {
            TokensData tdd = new TokensData();
            td = tdd.getTokenData();

            mockTokens = true;
        }

        uint256 len = td.length;

        unchecked {
            for (uint256 i; i < len; ++i) {
                addressOf[td[i].id] = td[i].addr;
                tokenIndexes[td[i].addr] = td[i].id;
                symbols[td[i].id] = td[i].symbol;
                tokenTypes[td[i].id] = td[i].tokenType;
                symbolToAsset[td[i].symbol] = td[i].id;

                _flushAccounts(td[i].addr);

                evm.label(td[i].addr, td[i].symbol);
            }
        }

        wethToken = addressOf[Tokens.WETH];
        tokenCount = len;
    }

    // function mint(
    //     address token,
    //     address to,
    //     uint256 amount
    // ) public override {
    //     Tokens index = tokenIndexes[token];
    //     require(index != Tokens.NO_TOKEN, "No token with such address");
    //     mint(index, to, amount);
    // }

    function _flushAccounts(address token) internal {
        _flushAccount(token, DUMB_ADDRESS);
        _flushAccount(token, DUMB_ADDRESS2);
        _flushAccount(token, DUMB_ADDRESS3);
        _flushAccount(token, DUMB_ADDRESS4);

        _flushAccount(token, USER);
        _flushAccount(token, LIQUIDATOR);
        _flushAccount(token, FRIEND);
        _flushAccount(token, FRIEND2);
    }

    function _flushAccount(address token, address account) internal {
        uint256 balance = IERC20(token).balanceOf(account);

        if (balance > 0) {
            evm.prank(account);
            IERC20(token).transfer(address(type(uint160).max), balance);
        }
    }

    function balanceOf(Tokens t, address holder) public view returns (uint256 balance) {
        balance = IERC20(addressOf[t]).balanceOf(holder);
    }

    // function approve(
    //     Tokens t,
    //     address holder,
    //     address targetContract
    // ) public {
    //     approve(t, holder, targetContract, type(uint256).max);
    // }

    // function approve(
    //     Tokens t,
    //     address holder,
    //     address targetContract,
    //     uint256 amount
    // ) public {
    //     evm.prank(holder);
    //     IERC20(addressOf[t]).approve(targetContract, amount);
    // }

    // function allowance(
    //     Tokens t,
    //     address holder,
    //     address targetContract
    // ) external view returns (uint256) {
    //     return IERC20(addressOf[t]).allowance(holder, targetContract);
    // }

    function transferFrom(Tokens t, address from, address to, uint256 amount) external {
        evm.prank(from);
        IERC20(addressOf[t]).transfer(to, amount);
    }

    function alignBalances(Tokens[] memory tokensToAlign, address targetAccount, address alignedAccount) external {
        for (uint256 i = 0; i < tokensToAlign.length; ++i) {
            uint256 targetBalance = balanceOf(tokensToAlign[i], targetAccount);
            uint256 currentBalance = balanceOf(tokensToAlign[i], alignedAccount);

            if (targetBalance > currentBalance) {
                mint(tokensToAlign[i], alignedAccount, targetBalance - currentBalance);
            } else if (currentBalance > targetBalance) {
                evm.prank(alignedAccount);
                IERC20(addressOf[tokensToAlign[i]]).transfer(address(0), currentBalance - targetBalance);
            }
        }
    }

    function burn(Tokens t, address from, uint256 amount) external {
        if (tokenTypes[t] != TokenType.NORMAL_TOKEN && mockTokens) {
            revert("tokenTestSuite: Trying to burn a non-normal token");
        }
        ERC20Mock(addressOf[t]).burn(from, amount);
    }

    function mint(address token, address to, uint256 amount) public override {
        _mint(token, to, amount, false);
    }

    function mintWithTotalSupply(address token, address to, uint256 amount) external {
        _mint(token, to, amount, true);
    }

    function mint(Tokens t, address to, uint256 amount) public {
        _mint(addressOf[t], to, amount, false);
    }

    function mintWithTotalSupply(Tokens t, address to, uint256 amount) public {
        _mint(addressOf[t], to, amount, true);
    }

    function _mint(address token, address to, uint256 amount, bool adjust) internal {
        if (mockTokens) {
            if (token == addressOf[Tokens.WETH]) {
                evm.deal(address(this), amount);
                IWETH(wethToken).deposit{value: amount}();
                IERC20(token).transfer(to, amount);
            } else if (token == addressOf[Tokens.STETH]) {
                evm.deal(address(this), amount);
                LidoMock(payable(token)).submit{value: amount}(address(this));
                IERC20(token).transfer(to, amount);
            } else if (tokenTypes[tokenIndexes[token]] == TokenType.C_TOKEN) {
                address underlying = cERC20Mock(token).underlying();
                mint(tokenIndexes[underlying], address(this), amount);
                IERC20(underlying).approve(token, amount);
                cERC20Mock(token).mint(address(this), amount);
                IERC20(token).transfer(to, amount);
            } else {
                // dealToken(token, to, amount, adjust);
                evm.prank(ERC20Mock(token).minter());
                ERC20Mock(token).mint(address(this), amount);
                IERC20(token).transfer(to, amount);
            }
        } else {
            if (token == addressOf[Tokens.LDO]) {
                evm.prank(LDO_DONOR);
                IERC20(token).transfer(to, amount);
            } else if (token == addressOf[Tokens.STETH]) {
                address stETH = addressOf[Tokens.STETH];
                evm.deal(to, amount);

                evm.prank(to);
                IstETH(payable(stETH)).submit{value: amount}(to);
            } else {
                dealToken(token, to, amount, adjust);
            }
        }
    }

    function approve(Tokens t, address holder, address targetContract) public {
        approve(t, holder, targetContract, type(uint256).max);
    }

    function approve(Tokens t, address holder, address targetContract, uint256 amount) public {
        evm.startPrank(holder);
        IERC20(addressOf[t]).safeApprove(targetContract, 0);
        IERC20(addressOf[t]).safeApprove(targetContract, amount);
        evm.stopPrank();
    }

    function approveMany(Tokens[] memory tokensToApprove, address holder, address target) public {
        uint256 len = tokensToApprove.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                approve(tokensToApprove[i], holder, target);
            }
        }
    }

    function allowance(Tokens t, address holder, address targetContract) external view returns (uint256) {
        return IERC20(addressOf[t]).allowance(holder, targetContract);
    }
}
