// SPDX-License-Identifier: Apache 2

pragma solidity >=0.8.9;

import "../ISenderAdapter.sol";
import "../MessageStruct.sol";

interface IWormhole {
    function publishMessage(
        uint32 nonce,
        bytes memory payload,
        uint8 consistencyLevel
    ) external payable returns (uint64 sequence);

    function messageFee() external view returns (uint256);
}

contract WormholeSenderAdapter is ISenderAdapter {
    string public name = "wormhole";
    address public immutable multiMsgSender;
    address public owner;
    address public receiverAdapter;

    uint8 consistencyLevel = 1;

    event MessageSent(bytes payload, address indexed messageReceiver);

    IWormhole private immutable wormhole;

    constructor(address _bridgeAddress, address _multiMsgSender) {
        wormhole = IWormhole(_bridgeAddress);
        multiMsgSender = _multiMsgSender;
        owner = msg.sender;
    }

    modifier onlyMultiBridgeSender() {
        require(msg.sender == multiMsgSender, "not multi-bridge msg sender");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "sender not owner");
        _;
    }

    function getMessageFee(MessageStruct.Message memory) external view override returns (uint256) {
        return wormhole.messageFee();
    }

    function sendMessage(MessageStruct.Message memory _message) external payable override onlyMultiBridgeSender {
        bytes memory payload = abi.encode(_message, receiverAdapter);
        wormhole.publishMessage{value: msg.value}(_message.nonce, payload, consistencyLevel);
        emit MessageSent(payload, receiverAdapter);
    }

    function setReceiverAdapter(address _receiverAdapter) external onlyOwner {
        receiverAdapter = _receiverAdapter;
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
