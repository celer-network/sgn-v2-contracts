// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../../framework/MessageApp.sol";

// a simple example to enforce in-order message delivery
contract MsgExampleInOrder is MessageApp {
    event MessageReceived(address srcContract, uint64 srcChainId, address sender, uint64 seq, bytes message);

    mapping(uint64 => mapping(address => uint64)) public sendSeq; // (dstChainId, dstContract) -> seq
    mapping(uint64 => mapping(address => uint64)) public recvSeq; // (srcChainId, srcContract) -> seq

    constructor(address _messageBus) MessageApp(_messageBus) {}

    // send message at source chain
    function sendMessage(
        address _dstContract,
        uint64 _dstChainId,
        bytes calldata _message
    ) external payable {
        uint64 seq = sendSeq[_dstChainId][_dstContract];
        bytes memory message = abi.encode(msg.sender, seq, _message);
        sendMessage(_dstContract, _dstChainId, message, msg.value);
        sendSeq[_dstChainId][_dstContract] += 1;
    }

    // receive message and destination chain
    function executeMessage(
        address _srcContract,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        (address sender, uint64 seq, bytes memory message) = abi.decode((_message), (address, uint64, bytes));
        uint64 expectedSeq = recvSeq[_srcChainId][_srcContract];
        if (seq != expectedSeq) {
            // sequence number not expected, let executor retry.
            // Note: cannot revert here, because once a message execute tx is reverted, it cannot be retried later.
            return ExecutionStatus.Retry;
        }
        emit MessageReceived(_srcContract, _srcChainId, sender, seq, message);
        recvSeq[_srcChainId][_srcContract] += 1;
        return ExecutionStatus.Success;
    }
}
