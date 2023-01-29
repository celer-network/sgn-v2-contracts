// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "./IMsgSender.sol";
import "../../interfaces/IMessageBus.sol";

contract CelerMsgSender is IMsgSender {
    string public constant name = "celer";
    address public immutable multiMsgSender;
    address public immutable msgBus;
    address public msgReceiver;

    modifier onlyMultiMsgSender() {
        require(msg.sender == multiMsgSender, "not multi-msg sender");
        _;
    }

    constructor(address _multiMsgSender, address _msgBus) {
        multiMsgSender = _multiMsgSender;
        msgBus = _msgBus;
    }

    function getMsgSenderName() external pure override returns (string memory) {
        return name;
    }

    function getMessageFee(IMsgSender.Message memory _message) external view override returns (uint256) {
        _message.bridgeName = name;
        return IMessageBus(msgBus).calcFee(abi.encode(_message));
    }

    function setMsgReceiver(address _msgReceiver) external override onlyMultiMsgSender {
        msgReceiver = _msgReceiver;
    }

    function sendMessage(IMsgSender.Message memory _message) external payable override onlyMultiMsgSender {
        _message.bridgeName = name;
        IMessageBus(msgBus).sendMessage{value: msg.value}(msgReceiver, _message.dstChainId, abi.encode(_message));
    }
}
