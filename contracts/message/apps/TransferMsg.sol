// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../framework/MsgSenderApp.sol";
import "../framework/MsgReceiverApp.sol";

// application to test msg only flow
contract TransferMsg is MsgSenderApp, MsgReceiverApp {
    constructor(
        address _msgbus
    ) {
        msgBus = _msgbus;
    }

    function transferMsg(
        address _receiver,
        uint64 _dstChainId,
        bytes memory _message
    ) external {
        sendMessage(_receiver, _dstChainId, _message);
    }

    function executeMessage(
        address,
        uint64,
        bytes calldata
    ) external override view onlyMessageBus returns (bool) {
        return true;
    }
}
