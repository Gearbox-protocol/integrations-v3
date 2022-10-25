// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Holdings, 2022
pragma solidity ^0.8.10;
pragma abicoder v1;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IBasicRewards {
    function getReward(address _account, bool _claimExtras) external;

    function getReward(address _account) external;

    function getReward(address _account, address _token) external;

    function stakeFor(address, uint256) external;
}

contract ClaimZapMock {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public immutable owner;
    address public immutable crv;
    address public immutable cvx;

    constructor(address _crv, address _cvx) {
        owner = msg.sender;
        crv = _crv;
        cvx = _cvx;
    }

    function getName() external pure returns (string memory) {
        return "ClaimZap V2.0";
    }

    function claimRewards(
        address[] calldata rewardContracts,
        address[] calldata extraRewardContracts,
        address[] calldata,
        address[] calldata,
        uint256 depositCrvMaxAmount,
        uint256 minAmountOut,
        uint256 depositCvxMaxAmount,
        uint256 spendCvxAmount,
        uint256 options
    ) external {
        //claim from main curve LP pools
        for (uint256 i = 0; i < rewardContracts.length; i++) {
            IBasicRewards(rewardContracts[i]).getReward(msg.sender, true);
        }
        //claim from extra rewards
        for (uint256 i = 0; i < extraRewardContracts.length; i++) {
            IBasicRewards(extraRewardContracts[i]).getReward(msg.sender);
        }

        _claimExtras(
            depositCrvMaxAmount,
            minAmountOut,
            depositCvxMaxAmount,
            spendCvxAmount,
            0,
            0,
            options
        );
    }

    function _claimExtras(
        uint256 depositCrvMaxAmount,
        uint256 minAmountOut,
        uint256 depositCvxMaxAmount,
        uint256 spendCvxAmount,
        uint256 removeCrvBalance,
        uint256 removeCvxBalance,
        uint256 options
    ) internal pure {
        require(
            depositCrvMaxAmount == 0,
            "Claim Zap Mock: Non-zero extra parameter was passed to target"
        );
        require(
            minAmountOut == 0,
            "Claim Zap Mock: Non-zero extra parameter was passed to target"
        );
        require(
            depositCvxMaxAmount == 0,
            "Claim Zap Mock: Non-zero extra parameter was passed to target"
        );
        require(
            spendCvxAmount == 0,
            "Claim Zap Mock: Non-zero extra parameter was passed to target"
        );
        require(
            removeCrvBalance == 0,
            "Claim Zap Mock: Non-zero extra parameter was passed to target"
        );
        require(
            removeCvxBalance == 0,
            "Claim Zap Mock: Non-zero extra parameter was passed to target"
        );
        require(
            options == 0,
            "Claim Zap Mock: Non-zero extra parameter was passed to target"
        );
    }
}
