// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

interface IMultiMsgReceiver {
    enum MessageType {
        ExternalMessage,
        InternalMessage
    }

    struct Message {
        MessageType messageType;
        string bridgeName;
        address multiMsgReceiver;
        uint64 dstChainId;
        uint32 nonce;
        address target;
        bytes callData;
    }

    function relayMessage(Message calldata _message) external;
}
