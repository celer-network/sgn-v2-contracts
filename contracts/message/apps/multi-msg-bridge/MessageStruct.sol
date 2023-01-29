// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

library MessageStruct {
    enum MessageType {
        ExternalMessage,
        InternalMessage
    }

    struct Message {
        MessageType messageType;
        string bridgeName;
        uint64 srcChainId;
        uint64 dstChainId;
        uint32 nonce;
        address target;
        bytes callData;
    }
}
