// SPDX-License-Identifier: UNLICENSED
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.23;

interface CreditManagerV3MockEvents {
    event Approve(address token, uint256 amount);
    event Execute();
}

contract CreditManagerV3Mock is CreditManagerV3MockEvents {
    address public pool;
    address public creditFacade;
    address public creditConfigurator;

    address internal _activeAccount;
    mapping(address => uint256) internal _tokenMasks;

    bytes _result;

    constructor(address _pool, address _creditFacade, address _creditConfigurator) {
        pool = _pool;
        creditFacade = _creditFacade;
        creditConfigurator = _creditConfigurator;
    }

    function approveCreditAccount(address token, uint256 amount) external {
        emit Approve(token, amount);
    }

    function execute(bytes memory) external returns (bytes memory result) {
        emit Execute();
        return _result;
    }

    function getTokenMaskOrRevert(address token) external view returns (uint256 mask) {
        mask = _tokenMasks[token];
        require(mask != 0, "Token not recognized");
    }

    function getActiveCreditAccountOrRevert() external view returns (address creditAccount) {
        creditAccount = _activeAccount;
        require(creditAccount != address(0), "Active account not set");
    }

    function setActiveCreditAccount(address creditAccount) external {
        _activeAccount = creditAccount;
    }

    function setMask(address token, uint256 mask) external {
        _tokenMasks[token] = mask;
    }

    function setExecuteResult(bytes memory result) external {
        _result = result;
    }
}
