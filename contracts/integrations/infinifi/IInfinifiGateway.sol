// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

struct UnwindingPosition {
    uint256 shares;
    uint32 fromEpoch;
    uint32 toEpoch;
    uint256 fromRewardWeight;
    uint256 rewardWeightDecrease;
}

interface IInfinifiGateway {
    function mint(address to, uint256 amount) external;

    function stake(address to, uint256 amount) external;

    function unstake(address to, uint256 amount) external;

    function createPosition(uint256 amount, uint32 unwindingEpochs, address recipient) external;

    function startUnwinding(uint256 shares, uint32 unwindingEpochs) external;

    function withdraw(uint256 unwindingTimestamp) external;

    function redeem(address to, uint256 amount, uint256 minAssetsOut) external;

    function claimRedemption() external;

    function getAddress(string memory name) external view returns (address);
}

interface IInfinifiMintController {
    function receiptToken() external view returns (address);
}

interface IInfinifiLockingController {
    function shareToken(uint32 unwindingEpochs) external view returns (address);

    function unwindingModule() external view returns (address);
}

interface IInfinifiUnwindingModule {
    function balanceOf(address user, uint256 unwindingTimestamp) external view returns (uint256);

    function positions(bytes32 id) external view returns (UnwindingPosition memory);
}

interface IInfinifiRedeemController {
    function receiptToAsset(uint256 amount) external view returns (uint256);
}
