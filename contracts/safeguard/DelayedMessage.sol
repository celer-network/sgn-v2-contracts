// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.17;

import "./Governor.sol";

abstract contract DelayedMessage is Governor {
    // universal unique id => delay start time
    // this id is not the msgId
    mapping(bytes32 => uint256) public delayedMessages;
    // dstContract => delay period
    mapping(address => uint256) public delayPeriods; // in seconds
    // in order to unify each message even in case of several same callData sent to the same dstContract
    uint32 public nonce;

    event DelayedMessageAdded(bytes32 id, address srcContract, uint64 srcChainId, address dstContract, bytes callData, uint32 nonce);
    event DelayedMessageExecuted(bytes32 id);

    event DelayPeriodUpdated(address receiver, uint256 period);

    function setDelayThresholds(address[] calldata _receivers, uint256[] calldata _periods) external onlyGovernor {
        require(_receivers.length == _periods.length, "length mismatch");
        for (uint256 i = 0; i < _receivers.length; i++) {
            delayPeriods[_receivers[i]] = _periods[i];
            emit DelayPeriodUpdated(_receivers[i], _periods[i]);
        }
    }

//    function setDelayPeriod(uint256 _period) external onlyGovernor {
//        delayPeriod = _period;
//        emit DelayPeriodUpdated(_period);
//    }

    function _addDelayedMessage(
        address _srcContract,
        uint64 _srcChainId,
        address _dstContract,
        bytes memory _callData
    ) internal {
        bytes32 id = keccak256(
            abi.encodePacked(
                _srcContract,
                _srcChainId,
                _dstContract,
                uint64(block.chainid),
                _callData,
                nonce
            )
        );
        require(delayedMessages[id] == 0, "delayed message already exists");
        delayedMessages[id] = uint256(block.timestamp);
        emit DelayedMessageAdded(id, _srcContract, _srcChainId, _dstContract, _callData, nonce);
        nonce += 1;
    }

    // caller needs to do the actual message execution
    function _executeDelayedMessage(
        address _srcContract,
        uint64 _srcChainId,
        address _dstContract,
        bytes memory _callData,
        uint32 _nonce
    ) internal {
        bytes32 id = keccak256(
            abi.encodePacked(
                _srcContract,
                _srcChainId,
                _dstContract,
                uint64(block.chainid),
                _callData,
                _nonce
            )
        );
        require(delayedMessages[id] > 0, "delayed message not exist");
        require(block.timestamp > delayedMessages[id] + delayPeriods[_dstContract], "delayed message still locked");
        delete delayedMessages[id];
        emit DelayedMessageExecuted(id);
    }
}
