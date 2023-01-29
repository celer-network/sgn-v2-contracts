// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./IMultiMsgReceiver.sol";
import "./MessageStruct.sol";

contract MultiMsgReceiver is IMultiMsgReceiver {
    mapping(address => uint32) public receiverAdaptersPower;
    enum MsgStatus {
        Unkonwn,
        Pending,
        Done
    }
    uint64 public powerThreshold;
    mapping(bytes32 => MsgStatus) public msgsStatus;
    mapping(bytes32 => uint64) public msgsPower;

    event ReceiverAdapterUpdated(address receiverAdapter, uint32 power);
    event PowerThresholdUpdated(uint64 powerThreshold);
    event SingleMsgReceived(
        uint64 indexed srcChainId,
        string indexed bridgeName,
        uint32 indexed nonce,
        address receiverAddr
    );
    event ExternalMsgExecuted(uint64 srcChainId, uint32 nonce, address target, bytes callData);
    event InternalMsgExecuted(uint64 srcChainId, uint32 nonce, bytes callData);

    modifier onlyReceiverAdapter() {
        require(receiverAdaptersPower[msg.sender] > 0, "not allowed receiver adapter");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "not self");
        _;
    }

    constructor(
        address[] memory _receiverAdapters,
        uint32[] memory _powers,
        uint64 _powerThreshold
    ) {
        require(_receiverAdapters.length == _powers.length, "mismatch length");
        for (uint256 i = 0; i < _receiverAdapters.length; i++) {
            _updateReceiverAdapter(_receiverAdapters[i], _powers[i]);
        }
        powerThreshold = _powerThreshold;
    }

    function receiveMessage(MessageStruct.Message calldata _message) external override onlyReceiverAdapter {
        bytes32 msgId = getMsgId(_message);
        if (msgsStatus[msgId] == MsgStatus.Unkonwn) {
            msgsStatus[msgId] = MsgStatus.Pending;
        }
        emit SingleMsgReceived(_message.srcChainId, _message.bridgeName, _message.nonce, msg.sender);
        msgsPower[msgId] += receiverAdaptersPower[msg.sender];
        _executeMessage(_message, msgId);
    }

    function updateMsgReceiver(address[] calldata _msgReceivers, uint32[] calldata _powers) external onlySelf {
        require(_msgReceivers.length == _powers.length, "mismatch length");
        for (uint256 i = 0; i < _msgReceivers.length; i++) {
            _updateReceiverAdapter(_msgReceivers[i], _powers[i]);
        }
    }

    function updatePowerThreshold(uint64 _powerThreshold) external onlySelf {
        powerThreshold = _powerThreshold;
        emit PowerThresholdUpdated(_powerThreshold);
    }

    function getMsgId(MessageStruct.Message calldata _message) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _message.messageType,
                    _message.srcChainId,
                    _message.dstChainId,
                    _message.nonce,
                    _message.target,
                    _message.callData
                )
            );
    }

    function _executeMessage(MessageStruct.Message calldata _message, bytes32 _msgId) private {
        if (msgsStatus[_msgId] == MsgStatus.Pending && msgsPower[_msgId] >= powerThreshold) {
            if (_message.messageType == MessageStruct.MessageType.ExternalMessage) {
                (bool ok, ) = _message.target.call(_message.callData);
                require(ok, "external message execution failed");
                emit ExternalMsgExecuted(_message.srcChainId, _message.nonce, _message.target, _message.callData);
            } else {
                (bool ok, ) = address(this).call(_message.callData);
                require(ok, "internal message execution failed");
                emit InternalMsgExecuted(_message.srcChainId, _message.nonce, _message.callData);
            }
            msgsStatus[_msgId] = MsgStatus.Done;
        }
    }

    function _updateReceiverAdapter(address _receiverAdapter, uint32 _power) private {
        receiverAdaptersPower[_receiverAdapter] = _power;
        emit ReceiverAdapterUpdated(_receiverAdapter, _power);
    }
}
