// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "./Addrs.sol";

abstract contract MsgReceiverApp is Addrs {
    modifier onlyMessagegBus() {
        require(msg.sender == msgBus, "caller is not message bus");
        _;
    }

    // ========= virtual functions to be implemented by apps =========

    function handleMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) internal virtual;

    function handleMessage(
        address _sender,
        uint64 _srcChainId,
        bytes memory _message
    ) internal virtual;

    // ============== functions called by the MessagegBus contract ==============

    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message
    ) external onlyMessagegBus {
        handleMessageWithTransfer(_sender, _token, _amount, _srcChainId, _message);
    }

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message
    ) external onlyMessagegBus {
        handleMessage(_sender, _srcChainId, _message);
    }
}
