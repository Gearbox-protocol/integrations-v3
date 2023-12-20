// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICreditFacadeV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3.sol";
import {ICreditFacadeV3Multicall} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditFacadeV3Multicall.sol";

import {IAdapter} from "@gearbox-protocol/core-v2/contracts/interfaces/IAdapter.sol";
import {AdapterType} from "@gearbox-protocol/sdk-gov/contracts/AdapterType.sol";
import {ICErc20, ICErc20Actions} from "../../../../integrations/compound/ICErc20.sol";
import {ICompoundV2_CTokenAdapter} from "../../../../interfaces/compound/ICompoundV2_CTokenAdapter.sol";
import {CompoundV2_Calls, CompoundV2_Multicaller} from "../../../multicall/compound/CompoundV2_Calls.sol";

import {Tokens} from "@gearbox-protocol/sdk-gov/contracts/Tokens.sol";
import {Contracts} from "@gearbox-protocol/sdk-gov/contracts/SupportedContracts.sol";

import {MultiCall} from "@gearbox-protocol/core-v2/contracts/libraries/MultiCall.sol";
import {MultiCallBuilder} from "@gearbox-protocol/core-v3/contracts/test/lib/MultiCallBuilder.sol";
import {AddressList} from "@gearbox-protocol/core-v3/contracts/test/lib/AddressList.sol";
// TEST
import "@gearbox-protocol/core-v3/contracts/test/lib/constants.sol";

// SUITES
import {LiveTestHelper} from "../../../suites/LiveTestHelper.sol";
import {BalanceComparator, BalanceBackup} from "../../../helpers/BalanceComparator.sol";

contract Live_CompoundV2EquivalenceTest is LiveTestHelper {
    using CompoundV2_Calls for CompoundV2_Multicaller;
    using AddressList for address[];

    string[5] stages = ["after_mint", "after_mintDiff", "after_redeem", "after_redeemDiff", "after_redeemUnderlying"];

    string[] _stages;

    function setUp() public {
        uint256 len = stages.length;
        _stages = new string[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                _stages[i] = stages[i];
            }
        }
    }

    /// HELPER

    function compareBehavior(
        address creditAccount,
        address cTokenAddress,
        address underlyingToken,
        bool isAdapter,
        BalanceComparator comparator
    ) internal {
        address cTokenShare = isAdapter ? ICompoundV2_CTokenAdapter(cTokenAddress).targetContract() : cTokenAddress;
        uint256 baseUnit = IERC20Metadata(underlyingToken).decimals();

        if (isAdapter) {
            CompoundV2_Multicaller cToken = CompoundV2_Multicaller(cTokenAddress);

            vm.startPrank(USER);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(cToken.mint(10 * baseUnit)));
            comparator.takeSnapshot("after_mint", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(cToken.mintDiff(10 * baseUnit)));
            comparator.takeSnapshot("after_mintDiff", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(cToken.redeem(5 * baseUnit)));
            comparator.takeSnapshot("after_redeem", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(cToken.redeemDiff(5 * baseUnit)));
            comparator.takeSnapshot("after_redeemDiff", creditAccount);

            creditFacade.multicall(creditAccount, MultiCallBuilder.build(cToken.redeemUnderlying(2 * baseUnit)));
            comparator.takeSnapshot("after_redeemUnderlying", creditAccount);

            vm.stopPrank();
        } else {
            ICErc20Actions cToken = ICErc20Actions(cTokenAddress);

            vm.startPrank(creditAccount);

            cToken.mint(10 * baseUnit);
            comparator.takeSnapshot("after_mint", creditAccount);

            uint256 amountToSwap = IERC20(underlyingToken).balanceOf(creditAccount) - 10 * baseUnit;
            cToken.mint(amountToSwap);
            comparator.takeSnapshot("after_mintDiff", creditAccount);

            cToken.redeem(5 * baseUnit);
            comparator.takeSnapshot("after_redeem", creditAccount);

            amountToSwap = IERC20(cTokenShare).balanceOf(creditAccount) - 5 * baseUnit;
            cToken.redeem(amountToSwap);
            comparator.takeSnapshot("after_redeemDiff", creditAccount);

            cToken.redeemUnderlying(2 * baseUnit);
            comparator.takeSnapshot("after_redeemUnderlying", creditAccount);

            vm.stopPrank();
        }
    }

    function openCreditAccountWithUnderlying(address token, uint256 amount) internal returns (address creditAccount) {
        vm.prank(USER);
        creditAccount = creditFacade.openCreditAccount(USER, MultiCallBuilder.build(), 0);

        tokenTestSuite.mint(token, creditAccount, amount);
    }

    function prepareComparator(address cTokenAdapter, address underlying)
        internal
        returns (BalanceComparator comparator)
    {
        address[] memory tokensToTrack = new address[](2);

        tokensToTrack[0] = underlying;
        tokensToTrack[1] = ICompoundV2_CTokenAdapter(cTokenAdapter).targetContract();

        Tokens[] memory _tokensToTrack = new Tokens[](tokensToTrack.length);

        for (uint256 j = 0; j < tokensToTrack.length; ++j) {
            _tokensToTrack[j] = tokenTestSuite.tokenIndexes(tokensToTrack[j]);
        }

        comparator = new BalanceComparator(_stages, _tokensToTrack, tokenTestSuite);
    }

    /// @dev [L-COMPV2ET-1]: CompoundV2 adapters and original contracts work identically
    function test_live_COMPV2ET_01_Compound_V2_adapters_and_original_contracts_are_equivalent()
        public
        attachOrLiveTest
    {
        address[] memory adapters = creditConfigurator.allowedAdapters();

        for (uint256 i = 0; i < adapters.length; ++i) {
            if (
                IAdapter(adapters[i])._gearboxAdapterType() != AdapterType.COMPOUND_V2_CERC20
                    && IAdapter(adapters[i])._gearboxAdapterType() != AdapterType.COMPOUND_V2_CETHER
            ) continue;

            uint256 snapshot0 = vm.snapshot();

            address underlying = ICompoundV2_CTokenAdapter(adapters[i])._gearboxAdapterType()
                == AdapterType.COMPOUND_V2_CETHER
                ? tokenTestSuite.addressOf(Tokens.WETH)
                : ICErc20(adapters[i]).underlying();

            address creditAccount =
                openCreditAccountWithUnderlying(underlying, 3000 * 10 ** IERC20Metadata(underlying).decimals());

            tokenTestSuite.approve(underlying, creditAccount, IAdapter(adapters[i]).targetContract());

            uint256 snapshot1 = vm.snapshot();

            BalanceComparator comparator = prepareComparator(adapters[i], underlying);

            compareBehavior(creditAccount, IAdapter(adapters[i]).targetContract(), underlying, false, comparator);

            BalanceBackup[] memory savedBalanceSnapshots = comparator.exportSnapshots(creditAccount);

            vm.revertTo(snapshot1);

            comparator = prepareComparator(adapters[i], underlying);

            compareBehavior(creditAccount, adapters[i], underlying, true, comparator);

            comparator.compareAllSnapshots(creditAccount, savedBalanceSnapshots, 0);

            vm.revertTo(snapshot0);
        }
    }
}
