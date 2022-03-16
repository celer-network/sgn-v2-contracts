// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../framework/MessageSenderApp.sol";
import "../framework/MessageReceiverApp.sol";

/** @title Application to test message only flow */
contract TransferMessage is MessageSenderApp, MessageReceiverApp {
    constructor(address _messageBus) {
        messageBus = _messageBus;
    }

    function transferMessage(
        address _receiver,
        uint64 _dstChainId,
        bytes memory _message
    ) external payable {
        sendMessage(_receiver, _dstChainId, _message, msg.value);
    }

    function executeMessage(
        address,
        uint64,
        bytes calldata,
        address
    ) external payable override onlyMessageBus returns (ExecuctionStatus) {
        return ExecuctionStatus.Success;
    }
}
