// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "../../../../interfaces/IMessageBus.sol";
import "../../interfaces/IBridgeSenderAdapter.sol";
import "../../MessageStruct.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CelerSenderAdapter is IBridgeSenderAdapter, Ownable {
    string public constant name = "celer";
    address public multiBridgeSender;
    address public immutable msgBus;
    // dstChainId => receiverAdapter address
    mapping(uint64 => address) public receiverAdapters;

    modifier onlyMultiBridgeSender() {
        require(msg.sender == multiBridgeSender, "not multi-bridge msg sender");
        _;
    }

    constructor(address _msgBus) {
        msgBus = _msgBus;
    }

    function getMessageFee(MessageStruct.Message memory _message) external view override returns (uint256) {
        _message.bridgeName = name;
        return IMessageBus(msgBus).calcFee(abi.encode(_message));
    }

    function sendMessage(MessageStruct.Message memory _message) external payable override onlyMultiBridgeSender {
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
        override
        onlyOwner
    {
        require(_dstChainIds.length == _receiverAdapters.length, "mismatch length");
        for (uint256 i = 0; i < _dstChainIds.length; i++) {
            receiverAdapters[_dstChainIds[i]] = _receiverAdapters[i];
        }
    }

    function setMultiBridgeSender(address _multiBridgeSender) external override onlyOwner {
        multiBridgeSender = _multiBridgeSender;
    }
}
