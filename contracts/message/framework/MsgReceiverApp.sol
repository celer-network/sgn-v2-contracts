// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "./MsgBusAddr.sol";

abstract contract MsgReceiverApp is MsgBusAddr {
    modifier onlyMessageBus() {
        require(msg.sender == msgBus, "caller is not message bus");
        _;
    }

    // ============== functions called by the MessageBus contract ==============

    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message
    ) external virtual onlyMessageBus {}

    // only called if executeMessageWithTransfer was reverted
    // app needs to decide what to do with the received tokens
    function executeMessageWithTransferFallback(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message
    ) external virtual onlyMessageBus {}

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message
    ) external virtual onlyMessageBus {}
}
