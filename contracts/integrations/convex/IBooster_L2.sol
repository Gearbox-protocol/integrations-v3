// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IBooster_L2 {
    function isShutdown() external view returns (bool);
    function withdrawTo(uint256, uint256, address) external;
    function claimCrv(uint256 _pid, address _gauge) external;
    function setGaugeRedirect(uint256 _pid) external returns (bool);
    function owner() external view returns (address);
    function rewardManager() external view returns (address);
    function feeDeposit() external view returns (address);
    function factoryCrv(address _factory) external view returns (address _crv);
    function calculatePlatformFees(uint256 _amount) external view returns (uint256);
    function addPool(address _lptoken, address _gauge, address _factory) external returns (bool);
    function shutdownPool(uint256 _pid) external returns (bool);
    function poolInfo(uint256)
        external
        view
        returns (address _lptoken, address _gauge, address _rewards, bool _shutdown, address _factory);
    function poolLength() external view returns (uint256);
    function activeMap(address) external view returns (bool);
    function fees() external view returns (uint256);
    function setPoolManager(address _poolM) external;
    function deposit(uint256 _pid, uint256 _amount) external returns (bool);
    function depositAll(uint256 _pid) external returns (bool);
}
