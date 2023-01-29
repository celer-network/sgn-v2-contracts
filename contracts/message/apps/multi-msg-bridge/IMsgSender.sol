// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

interface IMsgSender {
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

    function getMsgSenderName() external pure returns (string calldata);

    function getMessageFee(Message memory _message) external view returns (uint256);

    function setMsgReceiver(address _msgReceiver) external;

    function sendMessage(Message memory _message) external payable;
}
