// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./IMsgSender.sol";

contract UniswapMultiMsgSender {
    address[] public msgSenders;
    address public timelock;
    uint32 public nonce;

    event MultiMsgSent(
        uint64 dstChainId,
        address multiMsgReceiver,
        address target,
        bytes callData,
        address[] msgSenders
    );
    event MsgSenderAdded(address msgSenders);
    event MsgSenderRemoved(address msgSenders);

    modifier onlyTimelock() {
        require(msg.sender == timelock, "not uniswap timelock contract");
        _;
    }

    constructor(
        address _timelock,
        address[] memory _msgSenders,
        address[] memory _msgReceivers
    ) {
        timelock = _timelock;
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
    ) external payable onlyTimelock {
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
        }
        emit MultiMsgSent(_dstChainId, _multiMsgReceiver, _target, _callData, msgSenders);
    }

    function addMsgSenders(address[] calldata _msgSenders, address[] calldata _msgReceivers) external onlyTimelock {
        require(_msgSenders.length == _msgReceivers.length, "mismatch length");
        for (uint256 i = 0; i < _msgSenders.length; i++) {
            _addMsgSender(_msgSenders[i], _msgReceivers[i]);
        }
    }

    function removeMsgSenders(address[] calldata _msgSenders) external onlyTimelock {
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
