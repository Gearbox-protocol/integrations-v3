// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2024.
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";
import {IZircuitPool} from "../../../../integrations/zircuit/IZircuitPool.sol";
import {IZircuitPoolAdapter} from "../../../../interfaces/zircuit/IZircuitPoolAdapter.sol";

import {IPhantomToken} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";
import {ZircuitPhantomToken} from "../../../../helpers/zircuit/ZircuitPhantomToken.sol";
import {PriceFeedParams} from "@gearbox-protocol/core-v3/contracts/interfaces/IPriceOracleV3.sol";
import {IPriceFeed} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPriceFeed.sol";
import {IPhantomTokenWithdrawer} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IPhantomToken.sol";

import {ZircuitPoolCalls, ZircuitPoolMulticaller} from "../../../multicall/zircuit/ZircuitPool_Calls.sol";

import {IAdapter} from "@gearbox-protocol/core-v3/contracts/interfaces/base/IAdapter.sol";

import "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";

import {AddressList} from "@gearbox-protocol/core-v3/contracts/test/lib/AddressList.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES

import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

/// @notice This also includes Aura pools
contract Live_ZircuitEquivalenceTest is LiveTestHelper {
    using AddressList for address[];
    using ZircuitPoolCalls for ZircuitPoolMulticaller;

    string[4] stages = ["after_depositFor", "after_depositDiff", "after_withdraw", "after_withdrawDiff"];

    string[] _stages;

    function setUp() public {
        _setUp();

        /// @notice Sets comparator for this equivalence test

        uint256 len = stages.length;
        _stages = new string[](len);

        for (uint256 i; i < len; ++i) {
            _stages[i] = stages[i];
        }
    }

    /// HELPER

    function compareBehavior(
        address creditAccount,
        address zircuitAddress,
        address depositToken,
        bool adapters,
        BalanceComparator comparator
    ) internal {
        if (adapters) {
            ZircuitPoolMulticaller zircuit = ZircuitPoolMulticaller(zircuitAddress);

            vm.startPrank(USER);

            creditFacade.multicall(
                creditAccount, MultiCallBuilder.build(zircuit.depositFor(depositToken, creditAccount, WAD))
            );
            comparator.takeSnapshot("after_depositFor", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(zircuit.depositDiff(depositToken, WAD)));
            comparator.takeSnapshot("after_depositDiff", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(zircuit.withdraw(depositToken, WAD)));
            comparator.takeSnapshot("after_withdraw", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(zircuit.withdrawDiff(depositToken, WAD)));
            comparator.takeSnapshot("after_withdrawDiff", creditAccount);

            vm.stopPrank();
        } else {
            IZircuitPool zircuit = IZircuitPool(zircuitAddress);

            vm.startPrank(creditAccount);

            zircuit.depositFor(depositToken, creditAccount, WAD);
            comparator.takeSnapshot("after_depositFor", creditAccount);

            uint256 remainingBalance = IERC20(depositToken).balanceOf(creditAccount);
            zircuit.depositFor(depositToken, creditAccount, remainingBalance - WAD);
            comparator.takeSnapshot("after_depositDiff", creditAccount);

            zircuit.withdraw(depositToken, WAD);
            comparator.takeSnapshot("after_withdraw", creditAccount);

            remainingBalance = zircuit.balance(depositToken, creditAccount);
            zircuit.withdraw(depositToken, remainingBalance - WAD);
            comparator.takeSnapshot("after_withdrawDiff", creditAccount);

            vm.stopPrank();
        }
    }

    function openCreditAccountWithUnderlying(address token, uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        tokenTestSuite.mint(token, creditAccount, amount);
    }

    function prepareComparator(address depositToken, address phantomToken)
        internal
        returns (BalanceComparator comparator)
    {
        address[] memory tokensToTrack = new address[](2);

        tokensToTrack[0] = depositToken;
        tokensToTrack[1] = phantomToken;

        tokensToTrack = tokensToTrack.trim();

        uint256[] memory _tokensToTrack = new uint256[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    /// @dev [L-ZIRET-1]: Zircuit adapter works equivalently to direct interaction
    function test_live_ZIRET_01_Zircuit_adapter_and_original_contract_are_equivalent() public attachOrLiveTest {
        uint256 collateralTokensCount = creditManager.collateralTokensCount();

        address zircuitAdapter = getAdapter(address(creditManager), Contracts.ZIRCUIT_POOL);

        if (zircuitAdapter == address(0)) return;

        address zircuitPool = IAdapter(zircuitAdapter).targetContract();

        for (uint256 i = 0; i < collateralTokensCount; ++i) {
            address token = creditManager.getTokenByMask(1 << i);

            try IPhantomToken(token).getPhantomTokenInfo() returns (address target, address) {
                address adapter = creditManager.contractToAdapter(target);
                if (IAdapter(adapter).contractType() != "ADAPTER::ZIRCUIT_POOL") continue;
            } catch {
                continue;
            }

            address depositedToken = ZircuitPhantomToken(token).underlying();

            uint256 snapshot0 = vm.snapshot();

            address creditAccount = openCreditAccountWithUnderlying(depositedToken, 100 * WAD);

            tokenTestSuite.approve(depositedToken, creditAccount, zircuitPool);

            uint256 snapshot1 = vm.snapshot();

            BalanceComparator comparator = prepareComparator(depositedToken, token);

            compareBehavior(creditAccount, zircuitPool, depositedToken, false, comparator);

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot1);

            comparator = prepareComparator(depositedToken, token);

            compareBehavior(creditAccount, zircuitAdapter, depositedToken, true, comparator);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots);

            vm.revertTo(snapshot0);
        }
    }

    /// @dev [L-ZIRET-2]: Withdrawals for Zircuit phantom tokens work correctly
    function test_live_ZIRET_02_Zircuit_phantom_token_withdrawals_work_correctly() public attachOrLiveTest {
        uint256 collateralTokensCount = creditManager.collateralTokensCount();

        address zircuitAdapter = getAdapter(address(creditManager), Contracts.ZIRCUIT_POOL);

        if (zircuitAdapter == address(0)) return;

        for (uint256 i = 0; i < collateralTokensCount; ++i) {
            uint256 snapshot = vm.snapshot();

            address token = creditManager.getTokenByMask(1 << i);

            try IPhantomToken(token).getPhantomTokenInfo() returns (address target, address) {
                address adapter = creditManager.contractToAdapter(target);
                if (IAdapter(adapter).contractType() != "ADAPTER::ZIRCUIT_POOL") continue;
            } catch {
                continue;
            }

            if (priceOracle.reservePriceFeeds(token) == address(0)) {
                PriceFeedParams memory pfParams = priceOracle.priceFeedParams(token);
                vm.prank(Ownable(address(acl)).owner());
                priceOracle.setReservePriceFeed(token, pfParams.priceFeed, pfParams.stalenessPeriod);
            }

            address depositedToken = ZircuitPhantomToken(token).underlying();

            address creditAccount = openCreditAccountWithUnderlying(depositedToken, 100 * WAD);

            vm.prank(USER);
            creditFacade.multicall(
                creditAccount,
                MultiCallBuilder.build(
                    ZircuitPoolMulticaller(zircuitAdapter).depositFor(depositedToken, creditAccount, WAD)
                )
            );

            vm.expectCall(zircuitAdapter, abi.encodeCall(IPhantomTokenWithdrawer.withdrawPhantomToken, (token, WAD)));
            vm.prank(USER);
            MultiCall memory call = MultiCall({
                target: address(creditFacade),
                callData: abi.encodeCall(ICreditFacadeV3Multicall.withdrawCollateral, (token, WAD, USER))
            });

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(call));

            assertEq(IERC20(depositedToken).balanceOf(USER), WAD);

            vm.revertTo(snapshot);
        }
    }
}
