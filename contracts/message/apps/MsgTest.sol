// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../framework/MessageSenderApp.sol";
import "../framework/MessageReceiverApp.sol";

/** @title Application to test message with transfer refund flow */
contract MsgTest is MessageSenderApp, MessageReceiverApp {
    using SafeERC20 for IERC20;
    uint64 nonce;

    event MessageReceivedWithTransfer(
        address token,
        uint256 amount,
        address sender,
        uint64 srcChainId,
        address receiver,
        bytes message
    );
    event Refunded(address receiver, address token, uint256 amount, bytes message);
    event MessageReceived(address sender, uint64 srcChainId, uint256 nonce, bytes message);

    constructor(address _messageBus) {
        messageBus = _messageBus;
    }

    function sendMessageWithTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint32 _maxSlippage,
        bytes calldata _message,
        MsgDataTypes.BridgeSendType _bridgeSendType
    ) external payable {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        bytes memory message = abi.encode(msg.sender, _message);
        sendMessageWithTransfer(
            _receiver,
            _token,
            _amount,
            _dstChainId,
            nonce,
            _maxSlippage,
            message,
            _bridgeSendType,
            msg.value
        );
        nonce++;
    }

    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        (address receiver, bytes memory message) = abi.decode((_message), (address, bytes));
        IERC20(_token).safeTransfer(receiver, _amount);
        emit MessageReceivedWithTransfer(_token, _amount, _sender, _srcChainId, receiver, message);
        return ExecutionStatus.Success;
    }

    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        (address receiver, bytes memory message) = abi.decode((_message), (address, bytes));
        IERC20(_token).safeTransfer(receiver, _amount);
        emit Refunded(receiver, _token, _amount, message);
        return ExecutionStatus.Success;
    }

    function sendMessage(
        address _receiver,
        uint64 _dstChainId,
        bytes calldata _message
    ) external payable {
        bytes memory message = abi.encode(nonce, _message);
        nonce++;
        sendMessage(_receiver, _dstChainId, message, msg.value);
    }

    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        (uint256 n, bytes memory message) = abi.decode((_message), (uint64, bytes));
        emit MessageReceived(_sender, _srcChainId, n, message);
        return ExecutionStatus.Success;
    }
}
