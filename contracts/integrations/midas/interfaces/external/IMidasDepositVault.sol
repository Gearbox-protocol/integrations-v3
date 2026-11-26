// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @dev Ordinals match Midas `RequestStatus` (`Pending` / `Processed` / `Canceled`)
enum DepositStatus {
    PENDING,
    APPROVED,
    REJECTED
}

interface IMidasDepositVault {
    function depositInstant(address tokenIn, uint256 amountToken, uint256 minReceiveAmount, bytes32 referrerId)
        external
        returns (uint256);

    function depositInstant(
        address tokenIn,
        uint256 amountToken,
        uint256 minReceiveAmount,
        bytes32 referrerId,
        address tokensReceiver
    ) external returns (uint256);

    function depositRequest(address tokenIn, uint256 amountToken, bytes32 referrerId) external returns (uint256);

    function depositRequest(
        address tokenIn,
        uint256 amountToken,
        bytes32 referrerId,
        address recipientRequest,
        uint256 instantShare,
        uint256 minReceiveAmountInstantShare,
        address recipientInstant
    ) external returns (uint256, uint256);

    function currentRequestId() external view returns (uint256);

    function mintRequests(uint256 requestId)
        external
        view
        returns (
            address recipient,
            address tokenIn,
            DepositStatus status,
            uint256 depositedUsdAmount,
            uint256 usdAmountWithoutFees,
            uint256 tokenOutRate,
            uint256 depositedInstantUsdAmount,
            uint256 approvedTokenOutRate,
            uint256 amountMToken
        );

    function mToken() external view returns (address);
    function mTokenDataFeed() external view returns (address);
    function accessControl() external view returns (address);
    function greenlistedRole() external view returns (bytes32);
}
