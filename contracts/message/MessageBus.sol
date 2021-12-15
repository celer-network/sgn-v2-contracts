// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

contract MessageBus {
    event Message(address indexed sender, address receiver, uint256 dstChainId, bytes message);

    event MessageWithTransfer(
        address indexed sender,
        address receiver,
        uint256 dstChainId,
        address bridge,
        bytes32 srcTransferId,
        bytes message
    );

    function sendMessage(
        address _receiver,
        uint256 _dstChainId,
        bytes calldata _message
    ) external {
        emit Message(msg.sender, _receiver, _dstChainId, _message);
    }

    function sendMessageWithTransfer(
        address _receiver,
        uint256 _dstChainId,
        address _bridge,
        bytes32 _srcTransferId,
        bytes calldata _message
    ) external {
        // SGN needs to verify
        // 1. msg.sender matches sender of the src transfer
        // 2. dstChainId matches dstChainId of the src transfer
        emit MessageWithTransfer(msg.sender, _receiver, _dstChainId, _bridge, _srcTransferId, _message);
    }
}
