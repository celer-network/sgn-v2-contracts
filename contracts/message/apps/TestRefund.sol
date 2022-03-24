// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../framework/MessageSenderApp.sol";
import "../framework/MessageReceiverApp.sol";

/** @title Application to test message with transfer refund flow */
contract TestRefund is MessageSenderApp, MessageReceiverApp {
    using SafeERC20 for IERC20;

    event MessageReceivedWithTransfer(address token, uint256 amount, bytes message, address sender, uint64 srcChainId);
    event Refunded(address token, uint256 amount, bytes message);
    event MessageReceived(address receiver, uint64 dstChainId, bytes message);

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
        MessageSenderLib.BridgeType _bridgeType
    ) external payable {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        bytes memory message = abi.encode(msg.sender);
        sendMessageWithTransfer(
            _receiver,
            _token,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage,
            message,
            _bridgeType,
            msg.value
        );
    }

    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) external payable override onlyMessageBus returns (bool) {
        address receiver = abi.decode((_message), (address));
        IERC20(_token).safeTransfer(receiver, _amount);
        emit MessageReceivedWithTransfer(_token, _amount, _message, _sender, _srcChainId);
        return true;
    }

    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message
    ) external payable override onlyMessageBus returns (bool) {
        address sender = abi.decode((_message), (address));
        IERC20(_token).safeTransfer(sender, _amount);
        emit Refunded(_token, _amount, _message);
        return true;
    }

    function send(
        address _receiver,
        uint64 _dstChainId,
        bool _success
    ) external payable {
        bytes memory message = abi.encode(_success);
        sendMessage(_receiver, _dstChainId, message, msg.value);
    }

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message
    ) external payable override onlyMessageBus returns (bool) {
        bool success = abi.decode((_message), (bool));
        emit MessageReceived(_sender, _srcChainId, _message);
        return success;
    }
}
