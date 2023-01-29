// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./IMsgSender.sol";

contract MultiMsgSender {
    address[] public msgSenders;
    address public caller;
    uint32 public nonce;

    event SingleMsgSent(string indexed bridgeName, uint32 indexed nonce, address senderAddr);
    event MultiMsgSent(
        uint32 nonce,
        uint64 dstChainId,
        address multiMsgReceiver,
        address target,
        bytes callData,
        address[] msgSenders
    );
    event MsgSenderAdded(address msgSenders);
    event MsgSenderRemoved(address msgSenders);

    modifier onlyCaller() {
        require(msg.sender == caller, "not caller");
        _;
    }

    constructor(
        address _caller,
        address[] memory _msgSenders,
        address[] memory _msgReceivers
    ) {
        caller = _caller;
        require(_msgSenders.length == _msgReceivers.length, "mismatch length");
        for (uint256 i = 0; i < _msgSenders.length; i++) {
            _addMsgSender(_msgSenders[i], _msgReceivers[i]);
        }
    }

    function sendMessage(
        uint64 _dstChainId,
        address _multiMsgReceiver,
        address _target,
        bytes calldata _callData
    ) external payable onlyCaller {
        IMsgSender.Message memory message = IMsgSender.Message(
            IMsgSender.MessageType.ExternalMessage,
            "",
            _multiMsgReceiver,
            _dstChainId,
            nonce,
            _target,
            _callData
        );
        uint256 totalFee;
        for (uint256 i = 0; i < msgSenders.length; i++) {
            uint256 fee = IMsgSender(msgSenders[i]).getMessageFee(message);
            totalFee += fee;
            require(totalFee <= msg.value, "insufficient message fee");
            IMsgSender(msgSenders[i]).sendMessage{value: fee}(message);
            emit SingleMsgSent(IMsgSender(msgSenders[i]).getMsgSenderName(), nonce, msgSenders[i]);
        }
        emit MultiMsgSent(nonce, _dstChainId, _multiMsgReceiver, _target, _callData, msgSenders);
        nonce++;
    }

    function addMsgSenders(address[] calldata _msgSenders, address[] calldata _msgReceivers) external onlyCaller {
        require(_msgSenders.length == _msgReceivers.length, "mismatch length");
        for (uint256 i = 0; i < _msgSenders.length; i++) {
            _addMsgSender(_msgSenders[i], _msgReceivers[i]);
        }
    }

    function removeMsgSenders(address[] calldata _msgSenders) external onlyCaller {
        for (uint256 i = 0; i < _msgSenders.length; i++) {
            _removeMsgSender(_msgSenders[i]);
        }
    }

    function _addMsgSender(address _msgSender, address _msgReceiver) private {
        for (uint256 i = 0; i < msgSenders.length; i++) {
            if (msgSenders[i] == _msgSender) {
                return;
            }
        }
        msgSenders.push(_msgSender);
        IMsgSender(_msgSender).setMsgReceiver(_msgReceiver);
        emit MsgSenderAdded(_msgSender);
    }

    function _removeMsgSender(address _msgSender) private {
        uint256 lastIndex = msgSenders.length - 1;
        for (uint256 i = 0; i < msgSenders.length; i++) {
            if (msgSenders[i] == _msgSender) {
                if (i < lastIndex) {
                    msgSenders[i] = msgSenders[lastIndex];
                }
                msgSenders.pop();
                emit MsgSenderRemoved(_msgSender);
                return;
            }
        }
    }
}
