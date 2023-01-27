// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

import "../../safeguard/Ownable.sol";

abstract contract DelayedMessage is Ownable {
    // universal unique id (not msgId) => delay start time
    mapping(bytes32 => uint256) public delayedMessages;
    uint256 public delayPeriod; // in seconds
    uint32 public nonce;

    event DelayedMessageAdded(bytes32 id, address srcContract, uint64 srcChainId, bytes message, uint32 nonce);
    event DelayedMessageExecuted(bytes32 id);

    event DelayPeriodUpdated(uint256 period);

    function _addDelayedMessage(
        address _srcContract,
        uint64 _srcChainId,
        bytes calldata _message
    ) internal {
        bytes32 id = keccak256(abi.encodePacked(_srcContract, _srcChainId, _message, uint64(block.chainid), nonce));
        delayedMessages[id] = uint256(block.timestamp);
        emit DelayedMessageAdded(id, _srcContract, _srcChainId, _message, nonce);
        nonce += 1;
    }

    // caller needs to do the actual message execution
    function _executeDelayedMessage(
        address _srcContract,
        uint64 _srcChainId,
        bytes memory _message,
        uint32 _nonce
    ) internal {
        bytes32 id = keccak256(abi.encodePacked(_srcContract, _srcChainId, _message, uint64(block.chainid), _nonce));
        require(delayedMessages[id] > 0, "delayed message not exist");
        require(block.timestamp > delayedMessages[id] + delayPeriod, "delayed message still locked");
        delete delayedMessages[id];
        emit DelayedMessageExecuted(id);
    }

    function setDelayPeriod(uint256 _period) external onlyOwner {
        delayPeriod = _period;
        emit DelayPeriodUpdated(_period);
    }
}
