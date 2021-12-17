// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IBridge.sol";
import "./MessageBus.sol";
import "./MessageHandler.sol";

abstract contract AppTemplate is MessageHandler {
    using SafeERC20 for IERC20;

    address public msgBus;

    constructor(address _bridge, address _msgBus) MessageHandler(_bridge) {
        msgBus = _msgBus;
    }

    // called by application logic on source chain
    function transferWithMessage(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage,
        bytes memory _message
    ) internal {
        IERC20(_token).safeIncreaseAllowance(address(bridge), _amount);
        IBridge(bridge).send(_receiver, _token, _amount, _dstChainId, _nonce, _maxSlippage);
        bytes32 srcTransferId = computeSrcTransferId(_receiver, _token, _amount, _dstChainId, _nonce);
        MessageBus(msgBus).sendMessageWithTransfer(_receiver, _dstChainId, bridge, srcTransferId, _message);
    }

    function sendMessage(
        address _receiver,
        uint64 _dstChainId,
        bytes memory _message
    ) internal {
        MessageBus(msgBus).sendMessage(_receiver, _dstChainId, _message);
    }

    function computeSrcTransferId(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce
    ) private view returns (bytes32) {
        bytes32 transferId = keccak256(
            abi.encodePacked(address(this), _receiver, _token, _amount, _dstChainId, _nonce, uint64(block.chainid))
        );
        return transferId;
    }
}
