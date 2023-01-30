// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./IMultiBridgeReceiver.sol";
import "./MessageStruct.sol";

contract MultiBridgeReceiver is IMultiBridgeReceiver {
    // receiverAdapter => power of message bridge which this receiverAdapter belongs to
    mapping(address => uint32) public receiverAdaptersPower;
    // minimum accumulated power for each message to be executed
    uint64 public powerThreshold;

    enum MsgStatus {
        // default status which indicates a message has not been received yet
        Null,
        // Pending indicates a message has been received, but not has sufficient power
        Pending,
        // Done indicates a message has been received, and has been executed
        Done
    }
    struct MsgInfo {
        MsgStatus status;
        // current accumulated power
        uint64 power;
        // receiverAdapter => true/false; "true" means the msg from a certain receiverAdapter has been received.
        mapping(address => bool) from;
    }
    // msgId => MsgInfo
    mapping(bytes32 => MsgInfo) public msgInfos;

    event ReceiverAdapterUpdated(address receiverAdapter, uint32 power);
    event PowerThresholdUpdated(uint64 powerThreshold);
    event SingleBridgeMsgReceived(
        uint64 indexed srcChainId,
        string indexed bridgeName,
        uint32 indexed nonce,
        address receiverAddr
    );
    event MessageExecuted(uint64 srcChainId, uint32 nonce, address target, bytes callData);

    modifier onlyReceiverAdapter() {
        require(receiverAdaptersPower[msg.sender] > 0, "not allowed receiver adapter");
        _;
    }

    /**
     * @notice A modifier used for restricting the caller of some functions to be this contract itself.
     */
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

    /**
     * @notice Receive MessageStruct.Message from allowed receiverAdapter of message bridge.
     * This function call only be called once for each message by each allowed receiverAdapter.
     *
     * During function call, if the accumulated power of this message has reached or exceeded
     * the power threshold, this message will be executed immediately.
     *
     * Message execution would result in a solidity external message call, which has two possible type of target:
     * 1. other contract for whatever purpose;
     * 2. this contract for sake of adjusting params like receiverAdaptersPower or powerThreshold.
     */
    function receiveMessage(MessageStruct.Message calldata _message) external override onlyReceiverAdapter {
        bytes32 msgId = getMsgId(_message);
        MsgInfo storage msgInfo = msgInfos[msgId];
        if (msgInfo.status == MsgStatus.Null) {
            msgInfo.status = MsgStatus.Pending;
        } else {
            require(msgInfo.from[msg.sender] == false, "already received");
        }
        emit SingleBridgeMsgReceived(_message.srcChainId, _message.bridgeName, _message.nonce, msg.sender);
        msgInfo.power += receiverAdaptersPower[msg.sender];
        msgInfo.from[msg.sender] = true;
        _executeMessage(_message, msgInfo);
    }

    /**
     * @notice Update receiver adapter of message bridge.
     * Support updating multiple receiver adapters at once.
     *
     * This function can only be called during a call to receiveMessage().
     */
    function updateReceiverAdapter(address[] calldata _receiverAdapters, uint32[] calldata _powers) external onlySelf {
        require(_receiverAdapters.length == _powers.length, "mismatch length");
        for (uint256 i = 0; i < _receiverAdapters.length; i++) {
            _updateReceiverAdapter(_receiverAdapters[i], _powers[i]);
        }
    }

    /**
     * @notice Update power threshold of message execution.
     *
     * This function can only be called during a call to receiveMessage().
     */
    function updatePowerThreshold(uint64 _powerThreshold) external onlySelf {
        powerThreshold = _powerThreshold;
        emit PowerThresholdUpdated(_powerThreshold);
    }

    /**
     * @notice A helper function for getting id of a specific message.
     * MessageStruct.Message.bridgeName would not infect the calculation of msg id.
     */
    function getMsgId(MessageStruct.Message calldata _message) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _message.srcChainId,
                    _message.dstChainId,
                    _message.nonce,
                    _message.target,
                    _message.callData
                )
            );
    }

    function _executeMessage(MessageStruct.Message calldata _message, MsgInfo storage _msgInfo) private {
        if (_msgInfo.status == MsgStatus.Pending && _msgInfo.power >= powerThreshold) {
            (bool ok, ) = _message.target.call(_message.callData);
            require(ok, "external message execution failed");
            emit MessageExecuted(_message.srcChainId, _message.nonce, _message.target, _message.callData);
            _msgInfo.status = MsgStatus.Done;
        }
    }

    function _updateReceiverAdapter(address _receiverAdapter, uint32 _power) private {
        receiverAdaptersPower[_receiverAdapter] = _power;
        emit ReceiverAdapterUpdated(_receiverAdapter, _power);
    }
}
