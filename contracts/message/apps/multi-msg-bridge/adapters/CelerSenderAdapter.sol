// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "../../../interfaces/IMessageBus.sol";
import "../ISenderAdapter.sol";
import "../MessageStruct.sol";

contract CelerSenderAdapter is ISenderAdapter {
    string public constant name = "celer";
    address public immutable multiMsgSender;
    address public immutable msgBus;
    // dstChainId => receiverAdapter address
    mapping(uint64 => address) public receiverAdapters;
    address public owner;

    modifier onlyMultiMsgSender() {
        require(msg.sender == multiMsgSender, "not multi-msg sender");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _multiMsgSender, address _msgBus) {
        multiMsgSender = _multiMsgSender;
        msgBus = _msgBus;
        owner = msg.sender;
    }

    function getMessageFee(MessageStruct.Message memory _message) external view override returns (uint256) {
        _message.bridgeName = name;
        return IMessageBus(msgBus).calcFee(abi.encode(_message));
    }

    function sendMessage(MessageStruct.Message memory _message) external payable override onlyMultiMsgSender {
        _message.bridgeName = name;
        require(receiverAdapters[_message.dstChainId] != address(0), "no receiver adapter");
        IMessageBus(msgBus).sendMessage{value: msg.value}(
            receiverAdapters[_message.dstChainId],
            _message.dstChainId,
            abi.encode(_message)
        );
    }

    function updateReceiverAdapter(uint64[] calldata _dstChainIds, address[] calldata _receiverAdapters)
        external
        onlyOwner
    {
        require(_dstChainIds.length == _receiverAdapters.length, "mismatch length");
        for (uint256 i = 0; i < _dstChainIds.length; i++) {
            receiverAdapters[_dstChainIds[i]] = _receiverAdapters[i];
        }
    }

    function transferOwnership(address _to) external onlyOwner {
        owner = _to;
    }
}
