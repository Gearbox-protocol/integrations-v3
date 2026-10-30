// SPDX-License-Identifier: GPL-2.0-or-later
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2026.
pragma solidity ^0.8.23;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

struct SetPositionManagersParams {
    ISpoke.SetUserPositionManagers setPMs;
    bytes signature;
}

uint192 constant TOKENIZER_NONCE_KEY = uint192(keccak256("TOKENIZER_NONCE_KEY"));

contract AaveV4SpokeTokenizer is ERC4626 {
    address public immutable asset;

    address public immutable spoke;

    address public immutable reserveId;

    constructor(address _spoke, uint256 _reserveId) ERC4626(_asset) {
        spoke = _spoke;
        reserveId = _reserveId;
        asset = ISpoke(_spoke).getReserve(_reserveId).underlying;
        IERC20(asset).forceApprove(spoke, type(uint256).max);
    }

    function totalAssets() public view override returns (uint256) {
        return ISpoke(spoke).getUserSuppliedAssets(reserveId, address(this));
    }

    function wrap(uint256 assets, address receiver) public returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        require(assets <= maxAssets, ERC4626ExceededMaxDeposit(receiver, assets, maxAssets));

        uint256 shares = previewDeposit(assets);
        _wrap(assets, msg.sender, receiver);
        return shares;
    }

    function setPMAndWrap(SetPositionManagersParams memory params, uint256 assets, address receiver)
        external
        returns (uint256)
    {
        _setPM(params, msg.sender);
        return wrap(assets, receiver);
    }

    function setPMAndUnwrap(SetPositionManagersParams memory params, uint256 assets, address receiver, address owner)
        external
        returns (uint256)
    {
        _setPM(params, receiver);
        return unwrap(assets, receiver, owner);
    }

    function unwrap(uint256 assets, address receiver, address owner) public returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        require(assets <= maxAssets, ERC4626ExceededMaxWithdraw(owner, assets, maxAssets));

        uint256 shares = previewWithdraw(assets);
        _unwrap(assets, owner, receiver);

        return shares;
    }

    /// @dev Assumes this contract is set as position manager of `owner` in the corresponding Spoke
    function _wrap(address owner, address receiver, uint256 assets, uint256 shares) internal {
        ISpoke(spoke).withdraw(reserveId, assets, owner);
        _mint(receiver, shares);
        _ISpoke(spoke).supply(reserveId, assets, address(this));

        return shares;
    }

    /// @dev Assumes this contract is set as position manager of `receiver` in the corresponding Spoke
    function _unwrap(address caller, address owner, address receiver, uint256 assets, uint256 shares) internal {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        ISpoke(spoke).withdraw(reserveId, assets, address(this));

        _burn(owner, shares);
        ISpoke(spoke).supply(reserveId, assets, receiver);
    }

    function _setPM(SetPositionManagersParams memory params, address positionOwner) internal {
        if (
            params.setPMs.onBehalfOf != positionOwner || params.setPMs.updates.length != 1
                || params.setPMs.updates[0].positionManager != address(this) || !params.setPMs.updates[0].allowed
                || !_isCorrectNonce(positionOwner, params.setPMs.nonce)
        ) {
            revert InvalidSetPMParams(params);
        }

        ISpoke(spoke).setUserPositionManagersWithSig(params.setPMs, params.signature);
    }

    function _isCorrectNonce(address positionOwner, uint256 nonce) internal view returns (bool) {
        uint192 key = uint192(nonce >> 64);
        uint64 nonceValue = uint64(nonce);
        return key == TOKENIZER_NONCE_KEY && nonceValue == _getNonce(positionOwner);
    }

    function _getNonce(address positionOwner) internal view returns (uint256) {
        return ISpoke(spoke).nonces(positionOwner, TOKENIZER_NONCE_KEY) + 1;
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares);
        ISpoke(spoke).supply(reserveId, assets, address(this));
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        ISpoke(spoke).withdraw(reserveId, assets, address(this));
        super._withdraw(caller, receiver, owner, assets, shares);
    }
}
