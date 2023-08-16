pragma solidity ^0.8.10;

import "../token/StETHMock.sol";

interface ILidoMockEvents {
    event Mock_Submitted(address indexed sender, uint256 amount, address referral);
}

contract LidoMock is StETHMock, ILidoMockEvents {
    using SafeMath for uint256;

    receive() external payable {
        _submit(address(0));
    }

    function submit(address _referral) external payable returns (uint256) {
        return _submit(_referral);
    }

    function burnShares(address _account, uint256 _sharesAmount) external {
        _burnShares(_account, _sharesAmount);
    }

    /**
     * @dev Process user deposit, mints liquid tokens and increase the pool buffer
     * @param _referral address of referral.
     * @return amount of StETH shares generated
     */
    function _submit(address _referral) internal returns (uint256) {
        address sender = msg.sender;
        uint256 deposit = msg.value;
        require(deposit != 0, "ZERO_DEPOSIT");

        uint256 sharesAmount = getSharesByPooledEth(deposit);
        if (sharesAmount == 0) {
            // totalControlledEther is 0: either the first-ever deposit or complete slashing
            // assume that shares correspond to Ether 1-to-1
            sharesAmount = deposit;
        }

        totalPooledEtherSynced += deposit;

        _mintShares(sender, sharesAmount);
        _submitted(sender, deposit, _referral);
        _emitTransferAfterMintingShares(sender, sharesAmount);
        return sharesAmount;
    }

    function _emitTransferAfterMintingShares(address _to, uint256 _sharesAmount) internal {
        emit Transfer(address(0), _to, getPooledEthByShares(_sharesAmount));
    }

    function _submitted(address _sender, uint256 _value, address _referral) internal {
        emit Mock_Submitted(_sender, _value, _referral);
    }

    function syncExchangeRate(uint256 totalPooledEther, uint256 totalShares) external {
        totalPooledEtherSynced = totalPooledEther;
        totalSharesSynced = totalShares;
    }
}
