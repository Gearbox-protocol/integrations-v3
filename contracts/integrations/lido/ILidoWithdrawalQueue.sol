// SPDX-FileCopyrightText: 2023 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

struct WithdrawalRequestStatus {
    uint256 amountOfStETH;
    uint256 amountOfShares;
    address owner;
    uint256 timestamp;
    bool isFinalized;
    bool isClaimed;
}

interface ILidoWithdrawalQueue {
    function requestWithdrawals(uint256[] memory amounts, address owner)
        external
        returns (uint256[] memory requestIds);

    function requestWithdrawalsWstETH(uint256[] calldata amounts, address owner)
        external
        returns (uint256[] memory requestIds);

    function getWithdrawalStatus(uint256[] calldata _requestIds)
        external
        view
        returns (WithdrawalRequestStatus[] memory statuses);

    function claimWithdrawals(uint256[] calldata _requestIds, uint256[] calldata _hints) external;

    function findCheckpointHints(uint256[] calldata _requestIds, uint256 _firstIndex, uint256 _lastIndex)
        external
        view
        returns (uint256[] memory hintIds);

    function getClaimableEther(uint256[] calldata _requestIds, uint256[] calldata _hints)
        external
        view
        returns (uint256[] memory amounts);

    function getLastCheckpointIndex() external view returns (uint256);

    function STETH() external view returns (address);

    function WSTETH() external view returns (address);
}
