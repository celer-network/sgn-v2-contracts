// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "../framework/MessageSenderApp.sol";
import "../framework/MessageReceiverApp.sol";

/** @title Application to test message with transfer refund flow */
contract TestRefund is MessageSenderApp, MessageReceiverApp {
    event Refunded(address token, uint256 amount, bytes message);

    constructor(address _messageBus) {
        messageBus = _messageBus;
    }

    function sendWithTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage,
        MessageSenderLib.BridgeType _bridgeType,
        bytes calldata _message
    ) external payable {
        sendMessageWithTransfer(
            _receiver,
            _token,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage,
            _message,
            _bridgeType,
            0
        );
    }

    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message
    ) external payable virtual override onlyMessageBus returns (bool) {
        emit Refunded(_token, _amount, _message);
        return true;
    }

    function executeMessage(
        address,
        uint64,
        bytes calldata
    ) external payable override onlyMessageBus returns (bool) {
        return true;
    }
}
