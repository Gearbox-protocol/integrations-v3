// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

enum MellowProtocol {
    SYMBIOTIC,
    EIGEN_LAYER,
    ERC4626
}

struct Subvault {
    MellowProtocol protocol;
    address vault;
    address withdrawalQueue;
}

interface IMellowMultiVault {
    function asset() external view returns (address);
    function withdrawalQueue() external view returns (address);
    function subvaultsCount() external view returns (uint256);
    function subvaultAt(uint256 index) external view returns (Subvault memory);
    function depositWhitelist() external view returns (bool);
}

interface IMellowWithdrawalQueue {
    function pendingAssetsOf(address account) external view returns (uint256);
    function claimableAssetsOf(address account) external view returns (uint256);
}

interface IEigenLayerWithdrawalQueue {
    function getAccountData(
        address account,
        uint256 withdrawalsLimit,
        uint256 withdrawalsOffset,
        uint256 transferredWithdrawalsLimit,
        uint256 transferredWithdrawalsOffset
    )
        external
        view
        returns (uint256 claimableAssets, uint256[] memory withdrawals, uint256[] memory transferredWithdrawals);
}
