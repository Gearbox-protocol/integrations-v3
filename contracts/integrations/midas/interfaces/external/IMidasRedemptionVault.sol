// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @dev Ordinals match Midas `RequestStatus` (`Pending` / `Processed` / `Canceled`)
enum RedemptionStatus {
    PENDING,
    APPROVED,
    REJECTED
}

interface IMidasRedemptionVault {
    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount)
        external
        returns (uint256);

    function redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount, address recipient)
        external
        returns (uint256);

    function redeemRequest(address tokenOut, uint256 amountMTokenIn) external returns (uint256);

    function redeemRequest(
        address tokenOut,
        uint256 amountMTokenIn,
        address recipientRequest,
        uint256 instantShare,
        uint256 minReceiveAmountInstantShare,
        address recipientInstant
    ) external returns (uint256, uint256);

    function currentRequestId() external view returns (uint256);

    function redeemRequests(uint256 requestId)
        external
        view
        returns (
            address recipient,
            address tokenOut,
            RedemptionStatus status,
            uint256 amountMToken,
            uint256 mTokenRate,
            uint256 tokenOutRate,
            uint256 feePercent,
            uint256 amountMTokenInstant,
            uint256 approvedMTokenRate,
            uint256 amountTokenOut
        );

    function mToken() external view returns (address);
    function mTokenDataFeed() external view returns (address);
    function accessControl() external view returns (address);
    function greenlistedRole() external view returns (bytes32);
}
