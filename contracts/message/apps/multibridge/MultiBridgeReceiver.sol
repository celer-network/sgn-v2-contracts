// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.9;

import "./interfaces/IMultiBridgeReceiver.sol";
import "./MessageStruct.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiBridgeReceiver is IMultiBridgeReceiver, Ownable {
    uint256 public constant THRESHOLD_DECIMAL = 100;
    // minimum accumulated power precentage for each message to be executed
    uint64 public quorumThreshold;

    // receiverAdapter => power of bridge receive adapers
    mapping(address => uint64) public receiverAdapterPowers;
    // total power of all bridge adapters
    uint64 public totalPower;

    enum MsgStatus {
        Null, // default status which indicates a message has not been received yet
        Pending, // Pending indicates a message has been received, but not has sufficient power
        Done // Done indicates a message has been received, and has been executed
    }
    struct MsgInfo {
        MsgStatus status;
        uint64 power; // current accumulated power
        mapping(address => bool) from; // bridge receiver adapters that has already delivered this message.
    }
    // msgId => MsgInfo
    mapping(bytes32 => MsgInfo) public msgInfos;

    event ReceiverAdapterUpdated(address receiverAdapter, uint64 power);
    event QuorumThresholdUpdated(uint64 quorumThreshold);
    event SingleBridgeMsgReceived(uint64 srcChainId, string indexed bridgeName, uint32 nonce, address receiverAddr);
    event MessageExecuted(uint64 srcChainId, uint32 nonce, address target, bytes callData);

    modifier onlyReceiverAdapter() {
        require(receiverAdapterPowers[msg.sender] > 0, "not allowed bridge receiver adapter");
        _;
    }

    /**
     * @notice A modifier used for restricting the caller of some functions to be this contract itself.
     */
    modifier onlySelf() {
        require(msg.sender == address(this), "not self");
        _;
    }

    /**
     * @notice A one-time function to initialize contract states by the owner.
     * The contract ownership will be renounced at the end of this call.
     */
    function initialize(
        address[] memory _receiverAdapters,
        uint32[] memory _powers,
        uint64 _quorumThreshold
    ) external onlyOwner {
        require(_receiverAdapters.length == _powers.length, "mismatch length");
        for (uint256 i = 0; i < _receiverAdapters.length; i++) {
            _updateReceiverAdapter(_receiverAdapters[i], _powers[i]);
        }
        quorumThreshold = _quorumThreshold;
        renounceOwnership();
    }

    /**
     * @notice Receive messages from allowed bridge receiver adapters.
     * If the accumulated power of a message has reached the power threshold,
     * this message will be executed immediately, which will invoke an external function call
     * according to the message content.
     */
    function receiveMessage(MessageStruct.Message calldata _message) external override onlyReceiverAdapter {
        bytes32 msgId = getMsgId(_message);
        MsgInfo storage msgInfo = msgInfos[msgId];
        require(msgInfo.status != MsgStatus.Done, "message already executed");
        require(msgInfo.from[msg.sender] == false, "already received from this bridge adapter");
        msgInfo.from[msg.sender] = true;
        if (msgInfo.status == MsgStatus.Null) {
            msgInfo.status = MsgStatus.Pending;
        }
        emit SingleBridgeMsgReceived(_message.srcChainId, _message.bridgeName, _message.nonce, msg.sender);

        msgInfo.power += receiverAdapterPowers[msg.sender];
        _executeMessage(_message, msgInfo);
    }

    /**
     * @notice Update bridge receiver adapters.
     * This function can only be called by _executeMessage() invoked within receiveMessage() of this contract,
     * which means the only party who can make these updates is the caller of the MultiBridgeSender at the source chain.
     */
    function updateReceiverAdapter(address[] calldata _receiverAdapters, uint32[] calldata _powers) external onlySelf {
        require(_receiverAdapters.length == _powers.length, "mismatch length");
        for (uint256 i = 0; i < _receiverAdapters.length; i++) {
            _updateReceiverAdapter(_receiverAdapters[i], _powers[i]);
        }
    }

    /**
     * @notice Update power quorum threshold of message execution.
     * This function can only be called by _executeMessage() invoked within receiveMessage() of this contract,
     * which means the only party who can make these updates is the caller of the MultiBridgeSender at the source chain.
     */
    function updateQuorumThreshold(uint64 _quorumThreshold) external onlySelf {
        require(_quorumThreshold < THRESHOLD_DECIMAL, "invalid threshold");
        quorumThreshold = _quorumThreshold;
        emit QuorumThresholdUpdated(_quorumThreshold);
    }

    /**
     * @notice Compute message Id.
     * message.bridgeName is not included in the message id.
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

    /**
     * @notice Execute the message (invoke external call according to the message content) if the message
     * has reached the power threshold (the same message has been delivered by enough multiple bridges).
     */
    function _executeMessage(MessageStruct.Message calldata _message, MsgInfo storage _msgInfo) private {
        if (
            _msgInfo.status == MsgStatus.Pending && _msgInfo.power >= (totalPower * quorumThreshold) / THRESHOLD_DECIMAL
        ) {
            (bool ok, ) = _message.target.call(_message.callData);
            require(ok, "external message execution failed");
            _msgInfo.status = MsgStatus.Done;
            emit MessageExecuted(_message.srcChainId, _message.nonce, _message.target, _message.callData);
        }
    }

    function _updateReceiverAdapter(address _receiverAdapter, uint32 _power) private {
        totalPower -= receiverAdapterPowers[_receiverAdapter];
        totalPower += _power;
        receiverAdapterPowers[_receiverAdapter] = _power;
        emit ReceiverAdapterUpdated(_receiverAdapter, _power);
    }
}