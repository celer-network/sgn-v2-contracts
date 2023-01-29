// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./IMultiMsgReceiver.sol";

contract MultiMsgReceiver is IMultiMsgReceiver {
    mapping(address => uint32) public msgReceiversPower;
    enum MsgStatus {
        Unkonwn,
        Pending,
        Done
    }
    uint64 public powerThreshold;
    mapping(uint32 => MsgStatus) public msgsStatus;
    mapping(uint32 => uint64) public msgsPower;
    mapping(uint32 => bytes32) public msgsId;

    event MsgReceiverUpdated(address msgReceiver, uint32 power);
    event PowerThresholdUpdated(uint64 powerThreshold);
    event SingleMsgReceived(string indexed bridgeName, uint32 indexed nonce, address receiverAddr);
    event ExternalMsgExecuted(uint32 nonce, address target, bytes callData);
    event InternalMsgExecuted(uint32 nonce, bytes callData);

    modifier onlyMsgReceiver() {
        require(msgReceiversPower[msg.sender] > 0, "not allowed msg receiver");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "not self");
        _;
    }

    constructor(
        address[] memory _msgReceivers,
        uint32[] memory _powers,
        uint64 _powerThreshold
    ) {
        require(_msgReceivers.length == _powers.length, "mismatch length");
        for (uint256 i = 0; i < _msgReceivers.length; i++) {
            _updateMsgReceiver(_msgReceivers[i], _powers[i]);
        }
        powerThreshold = _powerThreshold;
    }

    function relayMessage(IMultiMsgReceiver.Message calldata _message) external override onlyMsgReceiver {
        require(address(this) == _message.multiMsgReceiver, "mismatch multi-msg receiver");
        bytes32 msgId = getMsgId(_message);
        if (msgsStatus[_message.nonce] == MsgStatus.Unkonwn) {
            msgsStatus[_message.nonce] = MsgStatus.Pending;
            msgsId[_message.nonce] = msgId;
        } else {
            require(msgsId[_message.nonce] == msgId, "mismatch message id");
        }
        emit SingleMsgReceived(_message.bridgeName, _message.nonce, msg.sender);
        msgsPower[_message.nonce] += msgReceiversPower[msg.sender];
        _executeMessage(_message);
    }

    function updateMsgReceiver(address[] calldata _msgReceivers, uint32[] calldata _powers) external onlySelf {
        require(_msgReceivers.length == _powers.length, "mismatch length");
        for (uint256 i = 0; i < _msgReceivers.length; i++) {
            _updateMsgReceiver(_msgReceivers[i], _powers[i]);
        }
    }

    function updatePowerThreshold(uint64 _powerThreshold) external onlySelf {
        powerThreshold = _powerThreshold;
        emit PowerThresholdUpdated(_powerThreshold);
    }

    function getMsgId(IMultiMsgReceiver.Message calldata _message) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_message.messageType, _message.nonce, _message.target, _message.callData));
    }

    function _executeMessage(IMultiMsgReceiver.Message calldata _message) private {
        if (msgsStatus[_message.nonce] == MsgStatus.Pending && msgsPower[_message.nonce] >= powerThreshold) {
            if (_message.messageType == IMultiMsgReceiver.MessageType.ExternalMessage) {
                (bool ok, ) = _message.target.call(_message.callData);
                require(ok, "external message execution failed");
                emit ExternalMsgExecuted(_message.nonce, _message.target, _message.callData);
            } else {
                (bool ok, ) = address(this).call(_message.callData);
                require(ok, "internal message execution failed");
                emit InternalMsgExecuted(_message.nonce, _message.callData);
            }
            msgsStatus[_message.nonce] = MsgStatus.Done;
        }
    }

    function _updateMsgReceiver(address _msgReceiver, uint32 _power) private {
        msgReceiversPower[_msgReceiver] = _power;
        emit MsgReceiverUpdated(_msgReceiver, _power);
    }
}
