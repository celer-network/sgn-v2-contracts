// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../framework/MessageApp.sol";

// A HelloWorld example for basic cross-chain message passing with associate cross-chain token transfer
contract MsgExampleBasicTransfer is MessageApp {
    using SafeERC20 for IERC20;

    event MessageWithTransferReceived(
        address sender,
        address token,
        uint256 amount,
        uint64 srcChainId,
        address receiver,
        bytes message
    );
    event MessageWithTransferRefunded(address sender, address token, uint256 amount, bytes message);

    constructor(address _messageBus) MessageApp(_messageBus) {}

    // send message with token transfer at the source chain
    function sendMessageWithTransfer(
        address _dstContract,
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage,
        bytes calldata _message,
        MsgDataTypes.BridgeSendType _bridgeSendType
    ) external payable {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        bytes memory message = abi.encode(msg.sender, _receiver, _message);
        sendMessageWithTransfer(
            _dstContract,
            _token,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage,
            message,
            _bridgeSendType,
            msg.value
        );
    }

    // receive message with token transfer at the destination chain
    function executeMessageWithTransfer(
        address, // srcContract
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        (address sender, address receiver, bytes memory message) = abi.decode((_message), (address, address, bytes));
        IERC20(_token).safeTransfer(receiver, _amount);
        emit MessageWithTransferReceived(sender, _token, _amount, _srcChainId, receiver, message);
        return ExecutionStatus.Success;
    }

    // handle refund of the transfer associated with the message at the source chain 
    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message,
        address // executor
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        (address sender, , bytes memory message) = abi.decode((_message), (address, address, bytes));
        IERC20(_token).safeTransfer(sender, _amount);
        emit MessageWithTransferRefunded(sender, _token, _amount, message);
        return ExecutionStatus.Success;
    }
}
