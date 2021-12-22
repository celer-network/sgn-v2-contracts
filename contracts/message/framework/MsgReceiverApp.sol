// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "./Addrs.sol";

abstract contract MsgReceiverApp is Addrs {
    modifier onlyMessagegBus() {
        require(msg.sender == msgBus, "caller is not message bus");
        _;
    }

    // ============== functions called by the MessagegBus contract ==============

    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message
    ) external virtual onlyMessagegBus {}

    function executeFailedMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message
    ) external virtual onlyMessagegBus {}

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message
    ) external virtual onlyMessagegBus {}
}
