// SPDX-License-Identifier: UNLICENSED
// Gearbox. Generalized leverage protocol that allows to take leverage and then use it across other DeFi protocols and platforms in a composable way.
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.10;

import {Tokens} from "@gearbox-protocol/sdk/contracts/Tokens.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// TEST

import "../lib/constants.sol";
import {TokensTestSuite} from "@gearbox-protocol/core-v3/contracts/test/suites/TokensTestSuite.sol";

struct BalanceBackup {
    string stage;
    Tokens token;
    uint256 balance;
}

address constant COMPARE_WITH = DUMB_ADDRESS;

contract BalanceComparator is Test {
    error StageNotAllowed(string);

    TokensTestSuite public tokenTestSuite;
    Tokens[] public tokensToTrack;
    mapping(string => mapping(Tokens => mapping(address => uint256))) savedBalances;

    string[] public stages;
    mapping(string => bool) _allowedStages;

    constructor(string[] memory _stages, Tokens[] memory _tokensToTrack, TokensTestSuite _tokenTestSuite) {
        tokenTestSuite = _tokenTestSuite;
        uint256 len = _tokensToTrack.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                tokensToTrack.push(_tokensToTrack[i]);
            }
        }

        len = _stages.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                stages.push(_stages[i]);
                _allowedStages[_stages[i]] = true;
            }
        }
    }

    function takeSnapshot(string memory stage, address holder) public {
        if (!_allowedStages[stage]) revert StageNotAllowed(stage);
        uint256 len = tokensToTrack.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                Tokens t = tokensToTrack[i];
                uint256 balance = IERC20(tokenTestSuite.addressOf(t)).balanceOf(holder);
                savedBalances[stage][t][holder] = balance;
            }
        }
    }

    function exportSnapshots(address holder) external view returns (BalanceBackup[] memory result) {
        uint256 lenStages = stages.length;
        uint256 len = tokensToTrack.length;
        unchecked {
            result = new BalanceBackup[](len * lenStages);

            for (uint256 j; j < lenStages; ++j) {
                for (uint256 i; i < len; ++i) {
                    Tokens t = tokensToTrack[i];
                    string memory stage = stages[j];

                    result[i + j * len] =
                        BalanceBackup({stage: stage, token: t, balance: savedBalances[stage][t][holder]});
                }
            }
        }
    }

    function compareAllSnapshots(address holder, BalanceBackup[] memory savedSnapshots) public {
        compareAllSnapshots(holder, savedSnapshots, 0);
    }

    function compareAllSnapshots(address holder, BalanceBackup[] memory savedSnapshots, uint256 expectedError) public {
        uint256 len = savedSnapshots.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                BalanceBackup memory b = savedSnapshots[i];
                savedBalances[b.stage][b.token][COMPARE_WITH] = b.balance;
            }
        }

        len = tokensToTrack.length;
        uint256 lenStages = stages.length;

        unchecked {
            for (uint256 j; j < lenStages; ++j) {
                for (uint256 i; i < len; ++i) {
                    Tokens t = tokensToTrack[i];
                    string memory stage = stages[j];

                    if (expectedError == 0) {
                        assertEq(
                            savedBalances[stage][t][holder],
                            savedBalances[stage][t][COMPARE_WITH],
                            string(
                                abi.encodePacked(
                                    "Balances are not equal for ", stage, " for ", tokenTestSuite.symbols(t)
                                )
                            )
                        );
                    } else {
                        uint256 diff = savedBalances[stage][t][holder] > savedBalances[stage][t][COMPARE_WITH]
                            ? savedBalances[stage][t][holder] - savedBalances[stage][t][COMPARE_WITH]
                            : savedBalances[stage][t][COMPARE_WITH] - savedBalances[stage][t][holder];

                        assertLe(
                            diff,
                            expectedError,
                            string(
                                abi.encodePacked(
                                    "Balance diff larger than expected error for ",
                                    stage,
                                    " for ",
                                    tokenTestSuite.symbols(t)
                                )
                            )
                        );
                    }
                }
            }
        }
    }
}
