// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "./IMsgSender.sol";
import "../../interfaces/IMessageBus.sol";

contract CelerMsgSender is IMsgSender {
    string public constant name = "celer";
    address public immutable uniswapMultiMsgSender;
    address public immutable msgBus;
    address public msgReceiver;

    modifier onlyUniswapMultiMsgSender() {
        require(msg.sender == uniswapMultiMsgSender, "not uniswap multi-msg sender");
        _;
    }

    constructor(address _uniswapMultiMsgSender, address _msgBus) {
        uniswapMultiMsgSender = _uniswapMultiMsgSender;
        msgBus = _msgBus;
    }

    function getMsgSenderName() external override pure returns (string memory) {
        return name;
    }

    function getMessageFee(IMsgSender.Message memory _message) external override view returns (uint256) {
        _message.senderName = name;
        return IMessageBus(msgBus).calcFee(abi.encode(_message));
    }

    function setMsgReceiver(address _msgReceiver) external override onlyUniswapMultiMsgSender {
        msgReceiver = _msgReceiver;
    }

    function sendMessage(IMsgSender.Message memory _message) external override payable onlyUniswapMultiMsgSender {
        _message.senderName = name;
        IMessageBus(msgBus).sendMessage{value: msg.value}(msgReceiver, _message.dstChainId, abi.encode(_message));
    }
}
